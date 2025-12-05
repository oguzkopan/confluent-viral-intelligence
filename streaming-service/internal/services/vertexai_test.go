package services

import (
	"context"
	"testing"

	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

func TestPredictVirality(t *testing.T) {
	cfg := &config.Config{
		GoogleCloudProject: "yarimai",
		VertexAILocation:   "us-central1",
	}

	client, err := NewVertexAIClient(context.Background(), cfg)
	if err != nil {
		t.Skipf("Skipping test - could not create Vertex AI client: %v", err)
		return
	}
	defer client.Close()

	tests := []struct {
		name     string
		req      models.ViralPredictionRequest
		wantProb float64 // Expected probability range
		minProb  float64
		maxProb  float64
	}{
		{
			name: "high engagement content",
			req: models.ViralPredictionRequest{
				PostID:             "post1",
				ViewCount:          1000,
				LikeCount:          200,
				CommentCount:       50,
				ShareCount:         30,
				RemixCount:         10,
				EngagementVelocity: 15.0,
				TimeElapsed:        10,
				ContentType:        "video",
			},
			minProb: 0.7,
			maxProb: 1.0,
		},
		{
			name: "moderate engagement content",
			req: models.ViralPredictionRequest{
				PostID:             "post2",
				ViewCount:          100,
				LikeCount:          20,
				CommentCount:       5,
				ShareCount:         2,
				RemixCount:         1,
				EngagementVelocity: 5.0,
				TimeElapsed:        30,
				ContentType:        "image",
			},
			minProb: 0.4,
			maxProb: 0.8,
		},
		{
			name: "low engagement content",
			req: models.ViralPredictionRequest{
				PostID:             "post3",
				ViewCount:          10,
				LikeCount:          1,
				CommentCount:       0,
				ShareCount:         0,
				RemixCount:         0,
				EngagementVelocity: 0.5,
				TimeElapsed:        60,
				ContentType:        "music",
			},
			minProb: 0.0,
			maxProb: 0.3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := client.PredictVirality(tt.req)
			if err != nil {
				t.Fatalf("PredictVirality() error = %v", err)
			}

			// Check viral probability is within bounds [0, 1]
			if resp.ViralProbability < 0.0 || resp.ViralProbability > 1.0 {
				t.Errorf("ViralProbability = %v, want between 0.0 and 1.0", resp.ViralProbability)
			}

			// Check viral probability is in expected range
			if resp.ViralProbability < tt.minProb || resp.ViralProbability > tt.maxProb {
				t.Errorf("ViralProbability = %v, want between %v and %v", resp.ViralProbability, tt.minProb, tt.maxProb)
			}

			// Check confidence is within bounds [0, 1]
			if resp.Confidence < 0.0 || resp.Confidence > 1.0 {
				t.Errorf("Confidence = %v, want between 0.0 and 1.0", resp.Confidence)
			}

			// Check predicted peak time is positive
			if resp.PredictedPeakTime <= 0 {
				t.Errorf("PredictedPeakTime = %v, want > 0", resp.PredictedPeakTime)
			}
		})
	}
}

func TestFallbackKeywordExtraction(t *testing.T) {
	cfg := &config.Config{
		GoogleCloudProject: "yarimai",
		VertexAILocation:   "us-central1",
	}

	client, err := NewVertexAIClient(context.Background(), cfg)
	if err != nil {
		t.Skipf("Skipping test - could not create Vertex AI client: %v", err)
		return
	}
	defer client.Close()

	tests := []struct {
		name        string
		prompt      string
		contentType string
		wantMinKw   int
		wantMaxKw   int
	}{
		{
			name:        "simple prompt",
			prompt:      "beautiful sunset over mountains",
			contentType: "image",
			wantMinKw:   5,
			wantMaxKw:   10,
		},
		{
			name:        "complex prompt",
			prompt:      "create an epic orchestral music piece with dramatic strings and powerful brass",
			contentType: "music",
			wantMinKw:   5,
			wantMaxKw:   10,
		},
		{
			name:        "short prompt",
			prompt:      "cat",
			contentType: "image",
			wantMinKw:   5,
			wantMaxKw:   10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := client.fallbackKeywordExtraction(tt.prompt, tt.contentType)

			// Check keyword count
			if len(resp.Keywords) < tt.wantMinKw || len(resp.Keywords) > tt.wantMaxKw {
				t.Errorf("Keywords count = %v, want between %v and %v", len(resp.Keywords), tt.wantMinKw, tt.wantMaxKw)
			}

			// Check category is set
			if resp.Category == "" {
				t.Error("Category is empty, want non-empty")
			}

			// Check style is set
			if resp.Style == "" {
				t.Error("Style is empty, want non-empty")
			}

			// Check mood is set
			if resp.Mood == "" {
				t.Error("Mood is empty, want non-empty")
			}
		})
	}
}

func TestCaching(t *testing.T) {
	cfg := &config.Config{
		GoogleCloudProject: "yarimai",
		VertexAILocation:   "us-central1",
	}

	client, err := NewVertexAIClient(context.Background(), cfg)
	if err != nil {
		t.Skipf("Skipping test - could not create Vertex AI client: %v", err)
		return
	}
	defer client.Close()

	// Test cache put and get
	key := "test:key"
	value := &models.KeywordExtractionResponse{
		Keywords: []string{"test", "cache"},
		Category: "test",
		Style:    "test",
		Mood:     "test",
	}

	// Put in cache
	client.putInCache(key, value)

	// Get from cache
	cached := client.getFromCache(key)
	if cached == nil {
		t.Fatal("Expected cached value, got nil")
	}

	cachedResp, ok := cached.(*models.KeywordExtractionResponse)
	if !ok {
		t.Fatal("Cached value is not KeywordExtractionResponse")
	}

	if len(cachedResp.Keywords) != len(value.Keywords) {
		t.Errorf("Cached keywords = %v, want %v", cachedResp.Keywords, value.Keywords)
	}

	// Test cache expiration
	client.cleanExpiredCache()

	// Cache should still exist (not expired yet)
	cached = client.getFromCache(key)
	if cached == nil {
		t.Error("Cache was cleaned too early")
	}
}
