package services

import (
	"context"
	"encoding/json"
	"fmt"

	aiplatform "cloud.google.com/go/aiplatform/apiv1"
	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/config"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/models"
	"google.golang.org/api/option"
	"google.golang.org/protobuf/types/known/structpb"
)

type VertexAIClient struct {
	predictionClient *aiplatform.PredictionClient
	config           *config.Config
	ctx              context.Context
}

func NewVertexAIClient(ctx context.Context, cfg *config.Config) (*VertexAIClient, error) {
	client, err := aiplatform.NewPredictionClient(ctx, option.WithEndpoint(fmt.Sprintf("%s-aiplatform.googleapis.com:443", cfg.VertexAILocation)))
	if err != nil {
		return nil, fmt.Errorf("failed to create prediction client: %w", err)
	}

	return &VertexAIClient{
		predictionClient: client,
		config:           cfg,
		ctx:              ctx,
	}, nil
}

// ExtractKeywords uses Gemini to extract keywords from content prompt
func (v *VertexAIClient) ExtractKeywords(prompt string, contentType string) (*models.KeywordExtractionResponse, error) {
	// Use Gemini for keyword extraction
	systemPrompt := `You are an AI content analyzer. Extract relevant keywords, category, style, and mood from the given content prompt.
Return a JSON object with:
- keywords: array of 5-10 relevant keywords
- category: main category (art, photography, music, voice, etc.)
- style: artistic style or genre
- mood: emotional tone

Example:
{
  "keywords": ["sunset", "mountains", "landscape", "nature", "golden hour"],
  "category": "photography",
  "style": "landscape",
  "mood": "peaceful"
}`

	userPrompt := fmt.Sprintf("Content Type: %s\nPrompt: %s", contentType, prompt)

	// Call Gemini API
	response, err := v.callGemini(systemPrompt, userPrompt)
	if err != nil {
		return nil, err
	}

	var result models.KeywordExtractionResponse
	if err := json.Unmarshal([]byte(response), &result); err != nil {
		// Fallback to simple keyword extraction
		return &models.KeywordExtractionResponse{
			Keywords: []string{contentType, "ai-generated"},
			Category: contentType,
			Style:    "unknown",
			Mood:     "neutral",
		}, nil
	}

	return &result, nil
}

// PredictVirality predicts if content will go viral
func (v *VertexAIClient) PredictVirality(req models.ViralPredictionRequest) (*models.ViralPredictionResponse, error) {
	// Calculate engagement score
	engagementScore := float64(req.LikeCount)*2 + float64(req.CommentCount)*3 + 
		float64(req.ShareCount)*5 + float64(req.RemixCount)*4

	// Calculate velocity factor (engagement per minute)
	velocityFactor := req.EngagementVelocity * 10

	// Simple viral probability calculation
	// In production, this would use a trained ML model
	viralScore := (engagementScore + velocityFactor) / float64(req.TimeElapsed+1)
	
	viralProbability := 0.0
	if viralScore > 100 {
		viralProbability = 0.9
	} else if viralScore > 50 {
		viralProbability = 0.7
	} else if viralScore > 20 {
		viralProbability = 0.5
	} else if viralScore > 10 {
		viralProbability = 0.3
	} else {
		viralProbability = 0.1
	}

	// Predict peak time based on current velocity
	predictedPeakTime := 60 // default 1 hour
	if req.EngagementVelocity > 10 {
		predictedPeakTime = 30 // 30 minutes for fast-growing content
	} else if req.EngagementVelocity > 5 {
		predictedPeakTime = 45
	}

	return &models.ViralPredictionResponse{
		ViralProbability:  viralProbability,
		Confidence:        0.85,
		PredictedPeakTime: predictedPeakTime,
	}, nil
}

// callGemini makes a request to Gemini API
func (v *VertexAIClient) callGemini(systemPrompt, userPrompt string) (string, error) {
	// Construct the request
	endpoint := fmt.Sprintf("projects/%s/locations/%s/publishers/google/models/gemini-pro:predict",
		v.config.GoogleCloudProject, v.config.VertexAILocation)

	// Create instance
	instance, err := structpb.NewStruct(map[string]interface{}{
		"content": userPrompt,
		"context": systemPrompt,
	})
	if err != nil {
		return "", err
	}

	req := &aiplatformpb.PredictRequest{
		Endpoint:  endpoint,
		Instances: []*structpb.Value{structpb.NewStructValue(instance)},
	}

	resp, err := v.predictionClient.Predict(v.ctx, req)
	if err != nil {
		return "", fmt.Errorf("prediction failed: %w", err)
	}

	if len(resp.Predictions) == 0 {
		return "", fmt.Errorf("no predictions returned")
	}

	// Extract response
	prediction := resp.Predictions[0]
	if content, ok := prediction.GetStructValue().Fields["content"]; ok {
		return content.GetStringValue(), nil
	}

	return "", fmt.Errorf("failed to extract content from response")
}

func (v *VertexAIClient) Close() error {
	return v.predictionClient.Close()
}
