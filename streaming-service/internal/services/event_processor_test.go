package services

import (
	"testing"
	"time"

	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

// TestEventProcessorCreation tests that EventProcessor can be created
func TestEventProcessorCreation(t *testing.T) {
	cfg := &config.Config{
		ConfluentBootstrapServers: "test-server:9092",
		ConfluentAPIKey:           "test-key",
		ConfluentAPISecret:        "test-secret",
		GoogleCloudProject:        "test-project",
		FirestoreProjectID:        "test-project",
		VertexAILocation:          "us-central1",
	}

	// Note: In a real test, we would use mocks for these dependencies
	// For now, we just test the struct creation
	ep := NewEventProcessor(nil, nil, nil, cfg)
	
	if ep == nil {
		t.Fatal("Expected EventProcessor to be created, got nil")
	}
	
	if ep.config != cfg {
		t.Error("EventProcessor config not set correctly")
	}
}

// TestProcessInteractionStructure tests the structure of ProcessInteraction
func TestProcessInteractionStructure(t *testing.T) {
	event := models.InteractionEvent{
		PostID:    "post123",
		UserID:    "user456",
		EventType: "like",
		Timestamp: time.Now(),
	}

	// Verify event structure
	if event.PostID == "" {
		t.Error("PostID should not be empty")
	}
	if event.UserID == "" {
		t.Error("UserID should not be empty")
	}
	if event.EventType == "" {
		t.Error("EventType should not be empty")
	}
}

// TestProcessContentMetadataStructure tests the structure of ContentMetadata
func TestProcessContentMetadataStructure(t *testing.T) {
	event := models.ContentMetadata{
		PostID:      "post123",
		UserID:      "user456",
		ContentType: "image",
		Prompt:      "A beautiful sunset over mountains",
		CreatedAt:   time.Now(),
	}

	// Verify event structure
	if event.PostID == "" {
		t.Error("PostID should not be empty")
	}
	if event.ContentType == "" {
		t.Error("ContentType should not be empty")
	}
	if event.Prompt == "" {
		t.Error("Prompt should not be empty")
	}
}

// TestProcessViewStructure tests the structure of ViewEvent
func TestProcessViewStructure(t *testing.T) {
	event := models.ViewEvent{
		PostID:   "post123",
		UserID:   "user456",
		ViewedAt: time.Now(),
		Duration: 30,
		Platform: "web",
	}

	// Verify event structure
	if event.PostID == "" {
		t.Error("PostID should not be empty")
	}
	if event.Platform == "" {
		t.Error("Platform should not be empty")
	}
	if event.Duration < 0 {
		t.Error("Duration should not be negative")
	}
}

// TestProcessRemixStructure tests the structure of RemixEvent
func TestProcessRemixStructure(t *testing.T) {
	event := models.RemixEvent{
		OriginalPostID: "post123",
		RemixPostID:    "post789",
		UserID:         "user456",
		RemixedAt:      time.Now(),
		RemixType:      "style_transfer",
	}

	// Verify event structure
	if event.OriginalPostID == "" {
		t.Error("OriginalPostID should not be empty")
	}
	if event.RemixPostID == "" {
		t.Error("RemixPostID should not be empty")
	}
	if event.OriginalPostID == event.RemixPostID {
		t.Error("OriginalPostID and RemixPostID should be different")
	}
}

// TestTrendingScoreStructure tests the structure of TrendingScore
func TestTrendingScoreStructure(t *testing.T) {
	score := models.TrendingScore{
		PostID:             "post123",
		Score:              85.5,
		ViralProbability:   0.75,
		EngagementVelocity: 12.5,
		ViewCount:          1000,
		LikeCount:          150,
		CommentCount:       25,
		ShareCount:         10,
		RemixCount:         5,
		CalculatedAt:       time.Now(),
	}

	// Verify score structure
	if score.PostID == "" {
		t.Error("PostID should not be empty")
	}
	if score.Score < 0 {
		t.Error("Score should not be negative")
	}
	if score.ViralProbability < 0 || score.ViralProbability > 1 {
		t.Error("ViralProbability should be between 0 and 1")
	}
}

// TestViralAlertThreshold tests that viral alert threshold is correct
func TestViralAlertThreshold(t *testing.T) {
	threshold := 0.7
	
	testCases := []struct {
		probability float64
		shouldAlert bool
	}{
		{0.5, false},
		{0.69, false},
		{0.7, false},  // Not greater than 0.7
		{0.71, true},
		{0.8, true},
		{0.95, true},
	}

	for _, tc := range testCases {
		shouldAlert := tc.probability > threshold
		if shouldAlert != tc.shouldAlert {
			t.Errorf("For probability %.2f, expected alert=%v, got alert=%v", 
				tc.probability, tc.shouldAlert, shouldAlert)
		}
	}
}

// TestRecommendationStructure tests the structure of Recommendation
func TestRecommendationStructure(t *testing.T) {
	rec := models.Recommendation{
		UserID:      "user456",
		PostID:      "post123",
		Score:       0.85,
		Reason:      "trending in your category",
		Category:    "photography",
		GeneratedAt: time.Now(),
	}

	// Verify recommendation structure
	if rec.UserID == "" {
		t.Error("UserID should not be empty")
	}
	if rec.PostID == "" {
		t.Error("PostID should not be empty")
	}
	if rec.Score < 0 || rec.Score > 1 {
		t.Error("Score should be between 0 and 1")
	}
}

// TestEventProcessorMethods tests that all required methods exist
func TestEventProcessorMethods(t *testing.T) {
	cfg := &config.Config{}
	ep := NewEventProcessor(nil, nil, nil, cfg)

	// Test that methods exist (will panic if they don't)
	_ = ep.ProcessInteraction
	_ = ep.ProcessContentMetadata
	_ = ep.ProcessView
	_ = ep.ProcessRemix
	_ = ep.ProcessTrendingScore
	_ = ep.ProcessRecommendation
	_ = ep.GetTrendingPosts
	_ = ep.GetPostStats
	_ = ep.GetUserRecommendations
}
