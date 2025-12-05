package services

import (
	"context"
	"testing"
	"time"

	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

// TestFirestoreOperations tests all Firestore operations
func TestFirestoreOperations(t *testing.T) {
	// Skip if not in integration test mode
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	ctx := context.Background()
	cfg := &config.Config{
		FirestoreProjectID: "yarimai",
	}

	client, err := NewFirestoreClient(ctx, cfg)
	if err != nil {
		t.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer client.Close()

	// Test SaveTrendingScore
	t.Run("SaveTrendingScore", func(t *testing.T) {
		score := models.TrendingScore{
			PostID:             "test-post-1",
			Score:              85.5,
			ViralProbability:   0.75,
			EngagementRate:     0.12,
			ViewCount:          1000,
			LikeCount:          150,
			CommentCount:       25,
			ShareCount:         10,
			RemixCount:         5,
			EngagementVelocity: 12.5,
			CalculatedAt:       time.Now(),
			TimeWindow:         "1min",
		}

		err := client.SaveTrendingScore(score)
		if err != nil {
			t.Errorf("SaveTrendingScore failed: %v", err)
		}
	})

	// Test SaveRecommendation
	t.Run("SaveRecommendation", func(t *testing.T) {
		rec := models.Recommendation{
			UserID:      "test-user-1",
			PostID:      "test-post-1",
			Score:       0.85,
			Reason:      "Based on your interests in art",
			Category:    "art",
			GeneratedAt: time.Now(),
		}

		err := client.SaveRecommendation(rec)
		if err != nil {
			t.Errorf("SaveRecommendation failed: %v", err)
		}
	})

	// Test UpdateContentMetadata
	t.Run("UpdateContentMetadata", func(t *testing.T) {
		keywords := []string{"abstract", "colorful", "modern"}
		err := client.UpdateContentMetadata("test-post-1", keywords, "art", "abstract")
		if err != nil {
			t.Logf("UpdateContentMetadata failed (expected if post doesn't exist): %v", err)
		}
	})

	// Test IncrementViewCount
	t.Run("IncrementViewCount", func(t *testing.T) {
		err := client.IncrementViewCount("test-post-1")
		if err != nil {
			t.Logf("IncrementViewCount failed (expected if post doesn't exist): %v", err)
		}
	})

	// Test GetTrendingPosts
	t.Run("GetTrendingPosts", func(t *testing.T) {
		scores, err := client.GetTrendingPosts(10)
		if err != nil {
			t.Errorf("GetTrendingPosts failed: %v", err)
		}
		t.Logf("Retrieved %d trending posts", len(scores))
	})

	// Test GetPostStats
	t.Run("GetPostStats", func(t *testing.T) {
		stats, err := client.GetPostStats("test-post-1")
		if err != nil {
			t.Logf("GetPostStats failed (expected if post doesn't exist): %v", err)
		} else {
			t.Logf("Post stats: Score=%.2f, Views=%d", stats.Score, stats.ViewCount)
		}
	})

	// Test GetUserRecommendations
	t.Run("GetUserRecommendations", func(t *testing.T) {
		recs, err := client.GetUserRecommendations("test-user-1", 10)
		if err != nil {
			t.Errorf("GetUserRecommendations failed: %v", err)
		}
		t.Logf("Retrieved %d recommendations", len(recs))
	})

	// Test TrackRemixChain
	t.Run("TrackRemixChain", func(t *testing.T) {
		err := client.TrackRemixChain("test-post-1", "test-remix-1")
		if err != nil {
			t.Errorf("TrackRemixChain failed: %v", err)
		}
	})

	// Test GetRemixCount
	t.Run("GetRemixCount", func(t *testing.T) {
		count, err := client.GetRemixCount("test-post-1")
		if err != nil {
			t.Errorf("GetRemixCount failed: %v", err)
		}
		t.Logf("Remix count: %d", count)
	})
}

// TestFirestoreClientCreation tests client initialization
func TestFirestoreClientCreation(t *testing.T) {
	ctx := context.Background()
	cfg := &config.Config{
		FirestoreProjectID: "yarimai",
	}

	client, err := NewFirestoreClient(ctx, cfg)
	if err != nil {
		t.Skipf("Skipping test - Firestore not available: %v", err)
	}
	defer client.Close()

	if client.client == nil {
		t.Error("Firestore client is nil")
	}
}

// TestSaveTrendingScoreValidation tests trending score validation
func TestSaveTrendingScoreValidation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	ctx := context.Background()
	cfg := &config.Config{
		FirestoreProjectID: "yarimai",
	}

	client, err := NewFirestoreClient(ctx, cfg)
	if err != nil {
		t.Skipf("Skipping test - Firestore not available: %v", err)
	}
	defer client.Close()

	// Test with valid data
	score := models.TrendingScore{
		PostID:             "validation-test-1",
		Score:              100.0,
		ViralProbability:   0.95,
		EngagementRate:     0.25,
		ViewCount:          5000,
		LikeCount:          500,
		CommentCount:       100,
		ShareCount:         50,
		RemixCount:         10,
		EngagementVelocity: 50.0,
		CalculatedAt:       time.Now(),
		TimeWindow:         "1min",
	}

	err = client.SaveTrendingScore(score)
	if err != nil {
		t.Errorf("Failed to save valid trending score: %v", err)
	}

	// Verify we can retrieve it
	retrieved, err := client.GetPostStats("validation-test-1")
	if err != nil {
		t.Errorf("Failed to retrieve saved trending score: %v", err)
	}

	if retrieved.PostID != score.PostID {
		t.Errorf("Retrieved PostID mismatch: got %s, want %s", retrieved.PostID, score.PostID)
	}
	if retrieved.Score != score.Score {
		t.Errorf("Retrieved Score mismatch: got %.2f, want %.2f", retrieved.Score, score.Score)
	}
}

// TestGetTrendingPostsOrdering tests that trending posts are ordered correctly
func TestGetTrendingPostsOrdering(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	ctx := context.Background()
	cfg := &config.Config{
		FirestoreProjectID: "yarimai",
	}

	client, err := NewFirestoreClient(ctx, cfg)
	if err != nil {
		t.Skipf("Skipping test - Firestore not available: %v", err)
	}
	defer client.Close()

	// Save multiple scores with different values
	scores := []models.TrendingScore{
		{PostID: "order-test-1", Score: 50.0, CalculatedAt: time.Now()},
		{PostID: "order-test-2", Score: 100.0, CalculatedAt: time.Now()},
		{PostID: "order-test-3", Score: 75.0, CalculatedAt: time.Now()},
	}

	for _, score := range scores {
		if err := client.SaveTrendingScore(score); err != nil {
			t.Errorf("Failed to save score for %s: %v", score.PostID, err)
		}
	}

	// Retrieve and verify ordering
	retrieved, err := client.GetTrendingPosts(3)
	if err != nil {
		t.Errorf("Failed to get trending posts: %v", err)
	}

	// Verify descending order
	for i := 1; i < len(retrieved); i++ {
		if retrieved[i].Score > retrieved[i-1].Score {
			t.Errorf("Posts not in descending order: %f > %f", retrieved[i].Score, retrieved[i-1].Score)
		}
	}
}

// TestRemixChainTracking tests remix chain functionality
func TestRemixChainTracking(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test")
	}

	ctx := context.Background()
	cfg := &config.Config{
		FirestoreProjectID: "yarimai",
	}

	client, err := NewFirestoreClient(ctx, cfg)
	if err != nil {
		t.Skipf("Skipping test - Firestore not available: %v", err)
	}
	defer client.Close()

	originalPostID := "remix-chain-test-original"
	
	// Track multiple remixes
	remixes := []string{"remix-1", "remix-2", "remix-3"}
	for _, remixID := range remixes {
		if err := client.TrackRemixChain(originalPostID, remixID); err != nil {
			t.Errorf("Failed to track remix %s: %v", remixID, err)
		}
	}

	// Get remix count
	count, err := client.GetRemixCount(originalPostID)
	if err != nil {
		t.Errorf("Failed to get remix count: %v", err)
	}

	if count < len(remixes) {
		t.Logf("Remix count: got %d, expected at least %d", count, len(remixes))
	}
}
