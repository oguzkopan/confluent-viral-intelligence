package services

import (
	"context"
	"fmt"
	"sort"
	"time"

	"cloud.google.com/go/firestore"
	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
	"google.golang.org/api/iterator"
)

type FirestoreClient struct {
	client *firestore.Client
	ctx    context.Context
}

func NewFirestoreClient(ctx context.Context, cfg *config.Config) (*FirestoreClient, error) {
	client, err := firestore.NewClient(ctx, cfg.FirestoreProjectID)
	if err != nil {
		return nil, fmt.Errorf("failed to create firestore client: %w", err)
	}

	return &FirestoreClient{
		client: client,
		ctx:    ctx,
	}, nil
}

// SaveTrendingScore saves trending score to Firestore
func (fc *FirestoreClient) SaveTrendingScore(score models.TrendingScore) error {
	_, err := fc.client.Collection("trending_scores").Doc(score.PostID).Set(fc.ctx, score)
	return err
}

// SaveRecommendation saves recommendation to Firestore
func (fc *FirestoreClient) SaveRecommendation(rec models.Recommendation) error {
	_, err := fc.client.Collection("recommendations").
		Doc(rec.UserID).
		Collection("items").
		Doc(rec.PostID).
		Set(fc.ctx, rec)
	return err
}

// UpdateContentMetadata updates content with keywords and category
func (fc *FirestoreClient) UpdateContentMetadata(postID string, keywords []string, category, style string) error {
	_, err := fc.client.Collection("posts").Doc(postID).Update(fc.ctx, []firestore.Update{
		{Path: "keywords", Value: keywords},
		{Path: "category", Value: category},
		{Path: "style", Value: style},
		{Path: "updated_at", Value: time.Now()},
	})
	return err
}

// IncrementViewCount increments view count for a post
func (fc *FirestoreClient) IncrementViewCount(postID string) error {
	_, err := fc.client.Collection("posts").Doc(postID).Update(fc.ctx, []firestore.Update{
		{Path: "view_count", Value: firestore.Increment(1)},
		{Path: "last_viewed_at", Value: time.Now()},
	})
	return err
}

// GetTrendingPosts retrieves top trending posts
func (fc *FirestoreClient) GetTrendingPosts(limit int) ([]models.TrendingScore, error) {
	// Get all documents and sort in memory (temporary workaround for index issues)
	iter := fc.client.Collection("trending_scores").
		Limit(100).
		Documents(fc.ctx)

	var scores []models.TrendingScore
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			fmt.Printf("Error fetching trending posts: %v\n", err)
			return nil, err
		}

		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			fmt.Printf("Error parsing document %s: %v\n", doc.Ref.ID, err)
			continue
		}
		scores = append(scores, score)
	}

	// Sort by score in descending order
	sort.Slice(scores, func(i, j int) bool {
		return scores[i].Score > scores[j].Score
	})

	// Limit results
	if len(scores) > limit {
		scores = scores[:limit]
	}

	fmt.Printf("Retrieved %d trending posts (sorted in memory)\n", len(scores))
	return scores, nil
}

// GetPostStats retrieves statistics for a specific post
func (fc *FirestoreClient) GetPostStats(postID string) (*models.TrendingScore, error) {
	doc, err := fc.client.Collection("trending_scores").Doc(postID).Get(fc.ctx)
	if err != nil {
		return nil, err
	}

	var score models.TrendingScore
	if err := doc.DataTo(&score); err != nil {
		return nil, err
	}

	return &score, nil
}

// GetUserRecommendations retrieves recommendations for a user
func (fc *FirestoreClient) GetUserRecommendations(userID string, limit int) ([]models.Recommendation, error) {
	iter := fc.client.Collection("recommendations").
		Doc(userID).
		Collection("items").
		OrderBy("score", firestore.Desc).
		Limit(limit).
		Documents(fc.ctx)

	var recs []models.Recommendation
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		var rec models.Recommendation
		if err := doc.DataTo(&rec); err != nil {
			continue
		}
		recs = append(recs, rec)
	}

	return recs, nil
}

// TrackRemixChain tracks remix relationships
func (fc *FirestoreClient) TrackRemixChain(originalPostID, remixPostID string) error {
	_, err := fc.client.Collection("remix_chains").Doc(originalPostID).Collection("remixes").Doc(remixPostID).Set(fc.ctx, map[string]interface{}{
		"remix_post_id": remixPostID,
		"created_at":    time.Now(),
	})
	return err
}

// GetRemixCount gets the number of remixes for a post
func (fc *FirestoreClient) GetRemixCount(postID string) (int, error) {
	iter := fc.client.Collection("remix_chains").Doc(postID).Collection("remixes").Documents(fc.ctx)
	count := 0
	for {
		_, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return 0, err
		}
		count++
	}
	return count, nil
}

// UpdatePostAnalytics updates post analytics based on interaction type
func (fc *FirestoreClient) UpdatePostAnalytics(postID string, eventType string) error {
	var field string
	switch eventType {
	case "like":
		field = "like_count"
	case "comment":
		field = "comment_count"
	case "share":
		field = "share_count"
	default:
		return nil
	}

	// Update the post document
	_, err := fc.client.Collection("posts").Doc(postID).Update(fc.ctx, []firestore.Update{
		{Path: field, Value: firestore.Increment(1)},
		{Path: "updated_at", Value: time.Now()},
	})
	
	// Also update or create trending score
	if err == nil {
		fc.UpdateTrendingScoreFromInteraction(postID, eventType)
	}
	
	return err
}

// UpdateTrendingScoreFromView updates trending score when a view occurs
func (fc *FirestoreClient) UpdateTrendingScoreFromView(postID string) error {
	scoreRef := fc.client.Collection("trending_scores").Doc(postID)
	
	// Get or create the score document
	doc, err := scoreRef.Get(fc.ctx)
	if err != nil {
		// Create new score document
		score := models.TrendingScore{
			PostID:       postID,
			ViewCount:    1,
			Score:        0.1,
			CalculatedAt: time.Now(),
		}
		_, err = scoreRef.Set(fc.ctx, score)
		return err
	}
	
	// Update existing score
	var score models.TrendingScore
	doc.DataTo(&score)
	
	score.ViewCount++
	score.Score = fc.calculateScore(score)
	score.CalculatedAt = time.Now()
	
	_, err = scoreRef.Set(fc.ctx, score)
	return err
}

// UpdateTrendingScoreFromInteraction updates trending score when an interaction occurs
func (fc *FirestoreClient) UpdateTrendingScoreFromInteraction(postID string, eventType string) error {
	scoreRef := fc.client.Collection("trending_scores").Doc(postID)
	
	// Get or create the score document
	doc, err := scoreRef.Get(fc.ctx)
	if err != nil {
		// Create new score document
		score := models.TrendingScore{
			PostID:       postID,
			Score:        1.0,
			CalculatedAt: time.Now(),
		}
		switch eventType {
		case "like":
			score.LikeCount = 1
		case "comment":
			score.CommentCount = 1
		case "share":
			score.ShareCount = 1
		}
		_, err = scoreRef.Set(fc.ctx, score)
		return err
	}
	
	// Update existing score
	var score models.TrendingScore
	doc.DataTo(&score)
	
	switch eventType {
	case "like":
		score.LikeCount++
	case "comment":
		score.CommentCount++
	case "share":
		score.ShareCount++
	}
	
	score.Score = fc.calculateScore(score)
	score.CalculatedAt = time.Now()
	
	_, err = scoreRef.Set(fc.ctx, score)
	return err
}

// UpdateTrendingScoreFromRemix updates trending score when a remix occurs
func (fc *FirestoreClient) UpdateTrendingScoreFromRemix(postID string) error {
	scoreRef := fc.client.Collection("trending_scores").Doc(postID)
	
	// Get or create the score document
	doc, err := scoreRef.Get(fc.ctx)
	if err != nil {
		// Create new score document
		score := models.TrendingScore{
			PostID:       postID,
			RemixCount:   1,
			Score:        2.0,
			CalculatedAt: time.Now(),
		}
		_, err = scoreRef.Set(fc.ctx, score)
		return err
	}
	
	// Update existing score
	var score models.TrendingScore
	doc.DataTo(&score)
	
	score.RemixCount++
	score.Score = fc.calculateScore(score)
	score.CalculatedAt = time.Now()
	
	_, err = scoreRef.Set(fc.ctx, score)
	return err
}

// calculateScore calculates trending score based on engagement metrics
func (fc *FirestoreClient) calculateScore(score models.TrendingScore) float64 {
	// Weighted scoring algorithm
	// Views: 0.1, Likes: 1.0, Comments: 2.0, Shares: 3.0, Remixes: 5.0
	return float64(score.ViewCount)*0.1 +
		float64(score.LikeCount)*1.0 +
		float64(score.CommentCount)*2.0 +
		float64(score.ShareCount)*3.0 +
		float64(score.RemixCount)*5.0
}

func (fc *FirestoreClient) Close() error {
	return fc.client.Close()
}
