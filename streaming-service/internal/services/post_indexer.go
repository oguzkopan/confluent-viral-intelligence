package services

import (
	"context"
	"confluent-viral-intelligence/internal/logger"
	"time"

	"confluent-viral-intelligence/internal/models"
	"google.golang.org/api/iterator"
)

// PostIndexer indexes all posts from the database into trending_scores
type PostIndexer struct {
	firestoreClient *FirestoreClient
	ctx             context.Context
}

// NewPostIndexer creates a new post indexer
func NewPostIndexer(firestoreClient *FirestoreClient) *PostIndexer {
	return &PostIndexer{
		firestoreClient: firestoreClient,
		ctx:             context.Background(),
	}
}

// IndexAllPosts indexes all posts from the posts collection into trending_scores
func (pi *PostIndexer) IndexAllPosts() error {
	startTime := time.Now()
	logger.Debug("📊 Starting full post indexing...")
	
	// Get all posts
	iter := pi.firestoreClient.client.Collection("posts").Documents(pi.ctx)
	
	indexedCount := 0
	updatedCount := 0
	errorCount := 0
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			logger.Debugf(" Error fetching post: %v", err)
			errorCount++
			continue
		}
		
		var postData map[string]interface{}
		if err := doc.DataTo(&postData); err != nil {
			logger.Debugf(" Error parsing post %s: %v", doc.Ref.ID, err)
			errorCount++
			continue
		}
		
		postID := doc.Ref.ID
		
		// Check if trending score already exists
		existingScore, err := pi.firestoreClient.GetPostStats(postID)
		if err == nil && existingScore != nil {
			// Update existing score with latest post data
			if err := pi.updateTrendingScoreFromPost(postID, postData, existingScore); err != nil {
				logger.Debugf(" Failed to update trending score for %s: %v", postID, err)
				errorCount++
			} else {
				updatedCount++
			}
			continue
		}
		
		// Create new trending score
		if err := pi.createTrendingScoreFromPost(postID, postData); err != nil {
			logger.Debugf(" Failed to create trending score for %s: %v", postID, err)
			errorCount++
		} else {
			indexedCount++
		}
	}
	
	duration := time.Since(startTime)
	logger.Infof("✅ Post indexing complete: indexed=%d, updated=%d, errors=%d, duration=%v", 
		indexedCount, updatedCount, errorCount, duration)
	
	return nil
}

// createTrendingScoreFromPost creates a new trending score from post data
func (pi *PostIndexer) createTrendingScoreFromPost(postID string, postData map[string]interface{}) error {
	score := models.TrendingScore{
		PostID:       postID,
		ViewCount:    getInt64(postData, "view_count"),
		LikeCount:    getInt64(postData, "like_count"),
		CommentCount: getInt64(postData, "comment_count"),
		ShareCount:   getInt64(postData, "share_count"),
		RemixCount:   getInt64(postData, "remix_count"),
		CalculatedAt: time.Now(),
	}
	
	// Get creation time for time decay calculation
	var createdAt time.Time
	if createdAtVal, ok := postData["created_at"].(time.Time); ok {
		createdAt = createdAtVal
	} else {
		createdAt = time.Now()
	}
	
	// Calculate score with time decay
	score.Score = pi.calculateScoreWithAge(score, createdAt)
	
	// Save to Firestore
	return pi.firestoreClient.SaveTrendingScore(score)
}

// updateTrendingScoreFromPost updates an existing trending score with latest post data
func (pi *PostIndexer) updateTrendingScoreFromPost(postID string, postData map[string]interface{}, existingScore *models.TrendingScore) error {
	// Update counts from post data
	existingScore.ViewCount = getInt64(postData, "view_count")
	existingScore.LikeCount = getInt64(postData, "like_count")
	existingScore.CommentCount = getInt64(postData, "comment_count")
	existingScore.ShareCount = getInt64(postData, "share_count")
	existingScore.RemixCount = getInt64(postData, "remix_count")
	
	// Get creation time for time decay calculation
	var createdAt time.Time
	if createdAtVal, ok := postData["created_at"].(time.Time); ok {
		createdAt = createdAtVal
	} else {
		createdAt = existingScore.CalculatedAt
	}
	
	// Recalculate score with time decay
	existingScore.Score = pi.calculateScoreWithAge(*existingScore, createdAt)
	existingScore.CalculatedAt = time.Now()
	
	// Save to Firestore
	return pi.firestoreClient.SaveTrendingScore(*existingScore)
}

// calculateScoreWithAge calculates score with time decay from a specific creation time
func (pi *PostIndexer) calculateScoreWithAge(score models.TrendingScore, createdAt time.Time) float64 {
	// Calculate hours since post creation
	hoursSinceCreation := time.Since(createdAt).Hours()
	
	// Avoid division by zero for very new posts
	if hoursSinceCreation < 0.1 {
		hoursSinceCreation = 0.1
	}
	
	// Weighted scoring algorithm
	// Views: 0.1, Likes: 1.0, Comments: 2.0, Shares: 3.0, Remixes: 5.0
	baseScore := float64(score.ViewCount)*0.1 +
		float64(score.LikeCount)*1.0 +
		float64(score.CommentCount)*2.0 +
		float64(score.ShareCount)*3.0 +
		float64(score.RemixCount)*5.0
	
	// Calculate engagement velocity (engagement per hour)
	totalEngagement := float64(score.LikeCount + score.CommentCount + score.ShareCount + score.RemixCount)
	engagementVelocity := totalEngagement / hoursSinceCreation
	
	// Apply time decay factor (exponential decay)
	// λ = 0.03 gives half-life of ~23 hours (faster decay for more dynamic trending)
	lambda := 0.03
	timeDecayFactor := 1.0 / (1.0 + lambda*hoursSinceCreation)
	
	// Recency bonus for new posts (last 24 hours)
	recencyBonus := 0.0
	if hoursSinceCreation < 24 {
		recencyBonus = 10.0 * (1.0 - hoursSinceCreation/24.0)
	}
	
	// Calculate final trending score with time decay and velocity
	trendingScore := (baseScore * timeDecayFactor) + (engagementVelocity * 5.0) + recencyBonus
	
	return trendingScore
}

// getInt64 safely extracts an int64 value from a map
func getInt64(data map[string]interface{}, key string) int64 {
	if val, ok := data[key]; ok {
		switch v := val.(type) {
		case int64:
			return v
		case int:
			return int64(v)
		case float64:
			return int64(v)
		}
	}
	return 0
}
