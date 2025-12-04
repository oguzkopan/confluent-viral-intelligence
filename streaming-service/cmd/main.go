package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/config"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/handlers"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/services"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Initialize services
	ctx := context.Background()

	// Kafka producer
	producer, err := services.NewKafkaProducer(cfg)
	if err != nil {
		log.Fatalf("Failed to create Kafka producer: %v", err)
	}
	defer producer.Close()

	// Firestore client
	firestoreClient, err := services.NewFirestoreClient(ctx, cfg)
	if err != nil {
		log.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer firestoreClient.Close()

	// Vertex AI client
	vertexAI, err := services.NewVertexAIClient(ctx, cfg)
	if err != nil {
		log.Fatalf("Failed to create Vertex AI client: %v", err)
	}
	defer vertexAI.Close()

	// Event processor
	eventProcessor := services.NewEventProcessor(producer, firestoreClient, vertexAI, cfg)

	// Start Kafka consumer in background
	consumer, err := services.NewKafkaConsumer(cfg, eventProcessor)
	if err != nil {
		log.Fatalf("Failed to create Kafka consumer: %v", err)
	}
	go consumer.Start(ctx)
	defer consumer.Close()

	// WebSocket hub
	wsHub := services.NewWebSocketHub()
	go wsHub.Run()

	// Setup HTTP server
	router := setupRouter(cfg, eventProcessor, wsHub)

	// Start server
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: router,
	}

	// Graceful shutdown
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	log.Printf("Server started on port %s", cfg.Port)

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exited")
}

func setupRouter(cfg *config.Config, processor *services.EventProcessor, wsHub *services.WebSocketHub) *gin.Engine {
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
			h := handlers.NewAnalyticsHandler(processor)
			analytics.GET("/trending", h.GetTrending)
			analytics.GET("/post/:id/stats", h.GetPostStats)
			analytics.GET("/user/:id/recommendations", h.GetRecommendations)
		}
	}

	// WebSocket endpoint
	router.GET("/ws", func(c *gin.Context) {
		handlers.HandleWebSocket(wsHub, c.Writer, c.Request)
	})

	return router
}
