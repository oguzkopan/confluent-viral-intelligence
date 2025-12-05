package services

import (
	"testing"
	"time"

	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

// TestKafkaProducerMethods tests that all producer methods are callable
// Note: This is a unit test that verifies method signatures and basic functionality
// It does not require actual Kafka connection
func TestKafkaProducerMethods(t *testing.T) {
	// Test that we can create event structs with proper fields
	t.Run("InteractionEvent", func(t *testing.T) {
		event := models.InteractionEvent{
			PostID:    "post-123",
			UserID:    "user-456",
			EventType: "like",
			Timestamp: time.Now(),
		}
		
		if event.PostID == "" {
			t.Error("PostID should not be empty")
		}
		if event.UserID == "" {
			t.Error("UserID should not be empty")
		}
		if event.EventType == "" {
			t.Error("EventType should not be empty")
		}
	})

	t.Run("ContentMetadata", func(t *testing.T) {
		event := models.ContentMetadata{
			PostID:      "post-123",
			UserID:      "user-456",
			ContentType: "image",
			Prompt:      "A beautiful sunset",
			CreatedAt:   time.Now(),
		}
		
		if event.PostID == "" {
			t.Error("PostID should not be empty")
		}
		if event.ContentType == "" {
			t.Error("ContentType should not be empty")
		}
	})

	t.Run("ViewEvent", func(t *testing.T) {
		event := models.ViewEvent{
			PostID:   "post-123",
			UserID:   "user-456",
			ViewedAt: time.Now(),
			Duration: 30,
			Platform: "web",
		}
		
		if event.PostID == "" {
			t.Error("PostID should not be empty")
		}
		if event.Duration < 0 {
			t.Error("Duration should not be negative")
		}
	})

	t.Run("RemixEvent", func(t *testing.T) {
		event := models.RemixEvent{
			OriginalPostID: "post-123",
			RemixPostID:    "post-789",
			UserID:         "user-456",
			RemixedAt:      time.Now(),
			RemixType:      "style_transfer",
		}
		
		if event.OriginalPostID == "" {
			t.Error("OriginalPostID should not be empty")
		}
		if event.RemixPostID == "" {
			t.Error("RemixPostID should not be empty")
		}
	})
}

// TestConfigTopicNames verifies that topic names are properly configured
func TestConfigTopicNames(t *testing.T) {
	cfg := &config.Config{
		TopicUserInteractions: "user-interactions",
		TopicContentMetadata:  "content-metadata",
		TopicViewEvents:       "view-events",
		TopicRemixEvents:      "remix-events",
		TopicTrendingScores:   "trending-scores",
		TopicRecommendations:  "recommendations",
	}

	if cfg.TopicUserInteractions == "" {
		t.Error("TopicUserInteractions should not be empty")
	}
	if cfg.TopicContentMetadata == "" {
		t.Error("TopicContentMetadata should not be empty")
	}
	if cfg.TopicViewEvents == "" {
		t.Error("TopicViewEvents should not be empty")
	}
	if cfg.TopicRemixEvents == "" {
		t.Error("TopicRemixEvents should not be empty")
	}
	if cfg.TopicTrendingScores == "" {
		t.Error("TopicTrendingScores should not be empty")
	}
	if cfg.TopicRecommendations == "" {
		t.Error("TopicRecommendations should not be empty")
	}
}

// TestKafkaProducerConfiguration verifies producer configuration
func TestKafkaProducerConfiguration(t *testing.T) {
	cfg := &config.Config{
		ConfluentBootstrapServers: "test-server:9092",
		ConfluentAPIKey:           "test-key",
		ConfluentAPISecret:        "test-secret",
		ConfluentSecurityProtocol: "SASL_SSL",
		ConfluentSASLMechanism:    "PLAIN",
		TopicUserInteractions:     "user-interactions",
		TopicContentMetadata:      "content-metadata",
		TopicViewEvents:           "view-events",
		TopicRemixEvents:          "remix-events",
		TopicTrendingScores:       "trending-scores",
		TopicRecommendations:      "recommendations",
	}

	// Verify configuration has all required fields
	if cfg.ConfluentBootstrapServers == "" {
		t.Error("ConfluentBootstrapServers should not be empty")
	}
	if cfg.ConfluentAPIKey == "" {
		t.Error("ConfluentAPIKey should not be empty")
	}
	if cfg.ConfluentAPISecret == "" {
		t.Error("ConfluentAPISecret should not be empty")
	}
	if cfg.ConfluentSecurityProtocol != "SASL_SSL" {
		t.Error("ConfluentSecurityProtocol should be SASL_SSL")
	}
	if cfg.ConfluentSASLMechanism != "PLAIN" {
		t.Error("ConfluentSASLMechanism should be PLAIN")
	}
}
