package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"net/http"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/handlers"
	"confluent-viral-intelligence/internal/logger"
	"confluent-viral-intelligence/internal/services"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Initialize logger
	logger.Init()

	// Load configuration
	cfg := config.Load()

	// Initialize services
	ctx := context.Background()

	// Kafka producer
	producer, err := services.NewKafkaProducer(cfg)
	if err != nil {
		logger.Fatalf("Failed to create Kafka producer: %v", err)
	}
	defer producer.Close()

	// Firestore client
	firestoreClient, err := services.NewFirestoreClient(ctx, cfg)
	if err != nil {
		logger.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer firestoreClient.Close()

	// Vertex AI client
	vertexAI, err := services.NewVertexAIClient(ctx, cfg)
	if err != nil {
		logger.Fatalf("Failed to create Vertex AI client: %v", err)
	}
	defer vertexAI.Close()

	// Event processor
	eventProcessor := services.NewEventProcessor(producer, firestoreClient, vertexAI, cfg)

	// Start Kafka consumer in background
	consumer, err := services.NewKafkaConsumer(cfg, eventProcessor)
	if err != nil {
		logger.Fatalf("Failed to create Kafka consumer: %v", err)
	}
	if err := consumer.Start(); err != nil {
		logger.Fatalf("Failed to start Kafka consumer: %v", err)
	}
	defer consumer.Close()

	// WebSocket hub
	wsHub := services.NewWebSocketHub()
	go wsHub.Run()

	// Start trending updater (recalculates scores every 5 minutes)
	trendingUpdater := services.NewTrendingUpdater(firestoreClient, 5*time.Minute)
	trendingUpdater.Start()
	defer trendingUpdater.Stop()

	// Create post indexer for initial indexing
	postIndexer := services.NewPostIndexer(firestoreClient)
	
	// Run initial indexing in background
	go func() {
		logger.Info("🚀 Starting initial post indexing...")
		if err := postIndexer.IndexAllPosts(); err != nil {
			logger.Errorf("❌ Initial indexing failed: %v", err)
		}
	}()

	// Setup HTTP server
	router := setupRouter(cfg, eventProcessor, wsHub, postIndexer)

	// Start server
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: router,
	}

	// Graceful shutdown
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("Failed to start server: %v", err)
		}
	}()

	logger.Infof("Server started on port %s", cfg.Port)

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown:" + err.Error())
	}

	logger.Info("Server exited")
}

func setupRouter(cfg *config.Config, processor *services.EventProcessor, wsHub *services.WebSocketHub, postIndexer *services.PostIndexer) *gin.Engine {
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// CORS configuration
	router.Use(cors.New(cors.Config{
		AllowOrigins:     cfg.AllowedOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})

	// API routes
	api := router.Group("/api")
	{
		// Event ingestion
		events := api.Group("/events")
		{
			h := handlers.NewEventHandler(processor)
			events.POST("/interaction", h.HandleInteraction)
			events.POST("/content", h.HandleContentMetadata)
			events.POST("/view", h.HandleView)
			events.POST("/remix", h.HandleRemix)
		}

		// Analytics
		analytics := api.Group("/analytics")
		{
			h := handlers.NewAnalyticsHandler(processor.GetFirestoreClient())
			analytics.GET("/trending", h.GetTrending)
			analytics.GET("/post/:id/stats", h.GetPostStats)
			analytics.GET("/user/:id/recommendations", h.GetRecommendations)
			
			// Dashboard analytics
			analytics.GET("/dashboard/metrics", h.GetDashboardMetrics)
			analytics.GET("/dashboard/top-creators", h.GetTopCreators)
			analytics.GET("/dashboard/content-types", h.GetContentTypeBreakdown)
			analytics.GET("/dashboard/trends", h.GetEngagementTrends)
		}

		// Admin operations
		admin := api.Group("/admin")
		{
			// Trigger full post indexing
			admin.POST("/index-posts", func(c *gin.Context) {
				go func() {
					if err := postIndexer.IndexAllPosts(); err != nil {
						logger.Errorf("❌ Post indexing failed: %v", err)
					}
				}()
				c.JSON(200, gin.H{"status": "indexing started"})
			})
		}
	}

	// WebSocket endpoint
	wsHandler := handlers.NewWebSocketHandler(wsHub)
	router.GET("/ws", wsHandler.HandleWebSocket)

	return router
}
