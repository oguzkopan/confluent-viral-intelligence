package services

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/config"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/models"
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
	iter := fc.client.Collection("trending_scores").
		OrderBy("score", firestore.Desc).
		Limit(limit).
		Documents(fc.ctx)

	var scores []models.TrendingScore
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			continue
		}
		scores = append(scores, score)
	}

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

func (fc *FirestoreClient) Close() error {
	return fc.client.Close()
}
