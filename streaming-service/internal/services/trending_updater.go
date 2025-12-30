package services

import (
	"context"
	"time"

	"confluent-viral-intelligence/internal/logger"
	"confluent-viral-intelligence/internal/models"
	"google.golang.org/api/iterator"
)

// TrendingUpdater periodically recalculates trending scores with time decay
type TrendingUpdater struct {
	firestoreClient *FirestoreClient
	ctx             context.Context
	cancel          context.CancelFunc
	updateInterval  time.Duration
}

// NewTrendingUpdater creates a new trending updater
func NewTrendingUpdater(firestoreClient *FirestoreClient, updateInterval time.Duration) *TrendingUpdater {
	ctx, cancel := context.WithCancel(context.Background())
	
	return &TrendingUpdater{
		firestoreClient: firestoreClient,
		ctx:             ctx,
		cancel:          cancel,
		updateInterval:  updateInterval,
	}
}

// Start begins the periodic update loop
func (tu *TrendingUpdater) Start() {
	logger.Infof("🔄 Starting trending updater with interval: %v", tu.updateInterval)
	
	// Run immediately on start
	tu.updateAllTrendingScores()
	
	// Then run periodically
	ticker := time.NewTicker(tu.updateInterval)
	go func() {
		for {
			select {
			case <-tu.ctx.Done():
				ticker.Stop()
				logger.Info("🛑 Trending updater stopped")
				return
			case <-ticker.C:
				tu.updateAllTrendingScores()
			}
		}
	}()
}

// Stop gracefully stops the updater
func (tu *TrendingUpdater) Stop() {
	tu.cancel()
}

// updateAllTrendingScores recalculates all trending scores with current time decay
func (tu *TrendingUpdater) updateAllTrendingScores() {
	startTime := time.Now()
	logger.Debug("🔄 Starting trending scores update...")
	
	// Get all trending scores
	iter := tu.firestoreClient.client.Collection("trending_scores").Documents(tu.ctx)
	
	updatedCount := 0
	errorCount := 0
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			// Silently skip errors to avoid log spam
			errorCount++
			continue
		}
		
		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			// Silently skip parsing errors
			errorCount++
			continue
		}
		
		// Recalculate score with current time decay
		newScore := tu.calculateDynamicScore(score)
		
		// Only update if score changed significantly (> 1% change)
		if abs(newScore-score.Score) > score.Score*0.01 {
			score.Score = newScore
			score.CalculatedAt = time.Now()
			
			// Update in Firestore
			if err := tu.firestoreClient.SaveTrendingScore(score); err != nil {
				// Silently skip save errors
				errorCount++
			} else {
				updatedCount++
			}
		}
	}
	
	duration := time.Since(startTime)
	// Only log summary at info level if there were updates or errors
	if updatedCount > 0 || errorCount > 0 {
		logger.Infof("✅ Trending scores update complete: updated=%d, errors=%d, duration=%v", 
			updatedCount, errorCount, duration)
	}
}

// calculateDynamicScore calculates trending score with time decay based on post creation time
func (tu *TrendingUpdater) calculateDynamicScore(score models.TrendingScore) float64 {
	// Get post creation time from Firestore
	postDoc, err := tu.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(tu.ctx)
	if err != nil {
		// If we can't get post creation time, use calculated_at as fallback
		return tu.calculateScoreWithAge(score, score.CalculatedAt)
	}
	
	var postData map[string]interface{}
	if err := postDoc.DataTo(&postData); err != nil {
		return tu.calculateScoreWithAge(score, score.CalculatedAt)
	}
	
	// Get creation time
	var createdAt time.Time
	if createdAtVal, ok := postData["created_at"].(time.Time); ok {
		createdAt = createdAtVal
	} else {
		createdAt = score.CalculatedAt
	}
	
	return tu.calculateScoreWithAge(score, createdAt)
}

// calculateScoreWithAge calculates score with time decay from a specific creation time
func (tu *TrendingUpdater) calculateScoreWithAge(score models.TrendingScore, createdAt time.Time) float64 {
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

// abs returns absolute value of float64
func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}
