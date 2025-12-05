package services

import (
	"log"
	"time"

	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

type EventProcessor struct {
	producer  *KafkaProducer
	firestore *FirestoreClient
	vertexAI  *VertexAIClient
	config    *config.Config
}

func NewEventProcessor(producer *KafkaProducer, firestore *FirestoreClient, vertexAI *VertexAIClient, cfg *config.Config) *EventProcessor {
	return &EventProcessor{
		producer:  producer,
		firestore: firestore,
		vertexAI:  vertexAI,
		config:    cfg,
	}
}

// GetFirestoreClient returns the Firestore client
func (ep *EventProcessor) GetFirestoreClient() *FirestoreClient {
	return ep.firestore
}

// ProcessInteraction handles user interaction events
func (ep *EventProcessor) ProcessInteraction(event models.InteractionEvent) error {
	// Publish to Kafka
	if err := ep.producer.PublishInteraction(event); err != nil {
		log.Printf("Failed to publish interaction: %v", err)
		return err
	}

	log.Printf("Processed interaction: %s on post %s", event.EventType, event.PostID)
	return nil
}

// ProcessInteractionForAnalytics updates analytics when consuming from Kafka
func (ep *EventProcessor) ProcessInteractionForAnalytics(event models.InteractionEvent) {
	// Update Firestore analytics based on interaction type
	if err := ep.firestore.UpdatePostAnalytics(event.PostID, event.EventType); err != nil {
		log.Printf("Failed to update analytics for interaction: %v", err)
	}
	log.Printf("Updated analytics for %s on post %s", event.EventType, event.PostID)
}

// ProcessViewForAnalytics updates analytics when consuming view events from Kafka
func (ep *EventProcessor) ProcessViewForAnalytics(event models.ViewEvent) {
	// Increment view count
	if err := ep.firestore.IncrementViewCount(event.PostID); err != nil {
		log.Printf("Failed to increment view count: %v", err)
	}
	
	// Update trending score
	if err := ep.firestore.UpdateTrendingScoreFromView(event.PostID); err != nil {
		log.Printf("Failed to update trending score: %v", err)
	}
	
	log.Printf("Updated analytics for view on post %s", event.PostID)
}

// ProcessRemixForAnalytics updates analytics when consuming remix events from Kafka
func (ep *EventProcessor) ProcessRemixForAnalytics(event models.RemixEvent) {
	// Track remix chain
	if err := ep.firestore.TrackRemixChain(event.OriginalPostID, event.RemixPostID); err != nil {
		log.Printf("Failed to track remix chain: %v", err)
	}
	
	// Update trending score for original post
	if err := ep.firestore.UpdateTrendingScoreFromRemix(event.OriginalPostID); err != nil {
		log.Printf("Failed to update trending score: %v", err)
	}
	
	log.Printf("Updated analytics for remix: %s -> %s", event.OriginalPostID, event.RemixPostID)
}

// ProcessContentMetadata handles content metadata and generates keywords
func (ep *EventProcessor) ProcessContentMetadata(event models.ContentMetadata) error {
	// Extract keywords using Vertex AI
	keywords, err := ep.vertexAI.ExtractKeywords(event.Prompt, event.ContentType)
	if err != nil {
		log.Printf("Failed to extract keywords: %v", err)
		// Continue with empty keywords
		keywords = &models.KeywordExtractionResponse{
			Keywords: []string{},
			Category: event.ContentType,
		}
	}

	// Update event with keywords
	event.Keywords = keywords.Keywords
	event.Category = keywords.Category
	event.Style = keywords.Style

	// Publish to Kafka
	if err := ep.producer.PublishContentMetadata(event); err != nil {
		log.Printf("Failed to publish content metadata: %v", err)
		return err
	}

	// Update Firestore
	if err := ep.firestore.UpdateContentMetadata(event.PostID, keywords.Keywords, keywords.Category, keywords.Style); err != nil {
		log.Printf("Failed to update content metadata in Firestore: %v", err)
	}

	log.Printf("Processed content metadata for post %s with %d keywords", event.PostID, len(keywords.Keywords))
	return nil
}

// ProcessView handles view events
func (ep *EventProcessor) ProcessView(event models.ViewEvent) error {
	// Publish to Kafka
	if err := ep.producer.PublishView(event); err != nil {
		log.Printf("Failed to publish view: %v", err)
		return err
	}

	// Increment view count in Firestore
	if err := ep.firestore.IncrementViewCount(event.PostID); err != nil {
		log.Printf("Failed to increment view count: %v", err)
	}

	log.Printf("Processed view for post %s by user %s", event.PostID, event.UserID)
	return nil
}

// ProcessRemix handles remix events
func (ep *EventProcessor) ProcessRemix(event models.RemixEvent) error {
	// Publish to Kafka
	if err := ep.producer.PublishRemix(event); err != nil {
		log.Printf("Failed to publish remix: %v", err)
		return err
	}

	// Track remix chain in Firestore
	if err := ep.firestore.TrackRemixChain(event.OriginalPostID, event.RemixPostID); err != nil {
		log.Printf("Failed to track remix chain: %v", err)
	}

	log.Printf("Processed remix: %s -> %s", event.OriginalPostID, event.RemixPostID)
	return nil
}

// ProcessTrendingScore handles trending score calculations from Flink
func (ep *EventProcessor) ProcessTrendingScore(score models.TrendingScore) {
	// Predict virality using Vertex AI
	prediction, err := ep.vertexAI.PredictVirality(models.ViralPredictionRequest{
		PostID:             score.PostID,
		ViewCount:          score.ViewCount,
		LikeCount:          score.LikeCount,
		CommentCount:       score.CommentCount,
		ShareCount:         score.ShareCount,
		RemixCount:         score.RemixCount,
		EngagementVelocity: score.EngagementVelocity,
		TimeElapsed:        int(time.Since(score.CalculatedAt).Minutes()),
	})

	if err != nil {
		log.Printf("Failed to predict virality: %v", err)
		prediction = &models.ViralPredictionResponse{
			ViralProbability: 0.5,
			Confidence:       0.5,
		}
	}

	// Update score with prediction
	score.ViralProbability = prediction.ViralProbability

	// Save to Firestore
	if err := ep.firestore.SaveTrendingScore(score); err != nil {
		log.Printf("Failed to save trending score: %v", err)
	}

	log.Printf("Processed trending score for post %s: score=%.2f, viral_prob=%.2f", 
		score.PostID, score.Score, score.ViralProbability)

	// If viral probability is high, trigger notifications
	if score.ViralProbability > 0.7 {
		log.Printf("🔥 VIRAL ALERT: Post %s has %.0f%% viral probability!", 
			score.PostID, score.ViralProbability*100)
		// TODO: Send push notifications
	}
}

// ProcessRecommendation handles personalized recommendations
func (ep *EventProcessor) ProcessRecommendation(rec models.Recommendation) {
	// Save to Firestore
	if err := ep.firestore.SaveRecommendation(rec); err != nil {
		log.Printf("Failed to save recommendation: %v", err)
	}

	log.Printf("Processed recommendation for user %s: post %s (score=%.2f)", 
		rec.UserID, rec.PostID, rec.Score)
}

// GetTrendingPosts retrieves trending posts
func (ep *EventProcessor) GetTrendingPosts(limit int) ([]models.TrendingScore, error) {
	return ep.firestore.GetTrendingPosts(limit)
}

// GetPostStats retrieves post statistics
func (ep *EventProcessor) GetPostStats(postID string) (*models.TrendingScore, error) {
	return ep.firestore.GetPostStats(postID)
}

// GetUserRecommendations retrieves user recommendations
func (ep *EventProcessor) GetUserRecommendations(userID string, limit int) ([]models.Recommendation, error) {
	return ep.firestore.GetUserRecommendations(userID, limit)
}
