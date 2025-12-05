package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/vertexai/genai"
	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
	"google.golang.org/api/option"
)

// cacheEntry represents a cached response with expiration
type cacheEntry struct {
	response  interface{}
	expiresAt time.Time
}

type VertexAIClient struct {
	genaiClient *genai.Client
	config      *config.Config
	ctx         context.Context
	cache       map[string]*cacheEntry
	cacheMutex  sync.RWMutex
	cacheTTL    time.Duration
}

func NewVertexAIClient(ctx context.Context, cfg *config.Config) (*VertexAIClient, error) {
	client, err := genai.NewClient(ctx, cfg.GoogleCloudProject, cfg.VertexAILocation, option.WithEndpoint(fmt.Sprintf("%s-aiplatform.googleapis.com:443", cfg.VertexAILocation)))
	if err != nil {
		return nil, fmt.Errorf("failed to create genai client: %w", err)
	}

	return &VertexAIClient{
		genaiClient: client,
		config:      cfg,
		ctx:         ctx,
		cache:       make(map[string]*cacheEntry),
		cacheTTL:    1 * time.Hour, // 1 hour TTL as per requirements
	}, nil
}

// ExtractKeywords uses Gemini to extract keywords from content prompt
func (v *VertexAIClient) ExtractKeywords(prompt string, contentType string) (*models.KeywordExtractionResponse, error) {
	// Check cache first
	cacheKey := fmt.Sprintf("keywords:%s:%s", contentType, prompt)
	if cached := v.getFromCache(cacheKey); cached != nil {
		if result, ok := cached.(*models.KeywordExtractionResponse); ok {
			return result, nil
		}
	}

	// System prompt for keyword extraction
	systemPrompt := `You are an AI content analyzer. Extract relevant keywords, category, style, and mood from the given content prompt.
Return ONLY a valid JSON object with these exact fields:
- keywords: array of 5-10 relevant keywords (strings)
- category: main category (art, photography, music, voice, video, text)
- style: artistic style or genre (string)
- mood: emotional tone (string)

Example response:
{
  "keywords": ["sunset", "mountains", "landscape", "nature", "golden hour"],
  "category": "photography",
  "style": "landscape",
  "mood": "peaceful"
}

Do not include any explanation, only return the JSON object.`

	userPrompt := fmt.Sprintf("Content Type: %s\nPrompt: %s\n\nExtract keywords, category, style, and mood from this prompt.", contentType, prompt)

	// Call Gemini API
	response, err := v.callGemini(systemPrompt, userPrompt)
	if err != nil {
		// Fallback to simple keyword extraction
		return v.fallbackKeywordExtraction(prompt, contentType), nil
	}

	// Parse JSON response
	var result models.KeywordExtractionResponse
	if err := json.Unmarshal([]byte(response), &result); err != nil {
		// Try to extract JSON from response if it contains extra text
		jsonStart := strings.Index(response, "{")
		jsonEnd := strings.LastIndex(response, "}")
		if jsonStart >= 0 && jsonEnd > jsonStart {
			jsonStr := response[jsonStart : jsonEnd+1]
			if err := json.Unmarshal([]byte(jsonStr), &result); err != nil {
				// Fallback to simple keyword extraction
				return v.fallbackKeywordExtraction(prompt, contentType), nil
			}
		} else {
			// Fallback to simple keyword extraction
			return v.fallbackKeywordExtraction(prompt, contentType), nil
		}
	}

	// Validate response
	if len(result.Keywords) < 5 || len(result.Keywords) > 10 {
		// Adjust keywords to be within range
		if len(result.Keywords) < 5 {
			// Add generic keywords
			result.Keywords = append(result.Keywords, contentType, "ai-generated", "creative", "digital", "content")
			if len(result.Keywords) > 10 {
				result.Keywords = result.Keywords[:10]
			}
		} else if len(result.Keywords) > 10 {
			result.Keywords = result.Keywords[:10]
		}
	}

	// Cache the result
	v.putInCache(cacheKey, &result)

	return &result, nil
}

// fallbackKeywordExtraction provides simple keyword extraction when AI fails
func (v *VertexAIClient) fallbackKeywordExtraction(prompt string, contentType string) *models.KeywordExtractionResponse {
	// Extract simple keywords from prompt
	words := strings.Fields(strings.ToLower(prompt))
	keywords := []string{contentType, "ai-generated"}
	
	// Add first few meaningful words from prompt
	for _, word := range words {
		if len(word) > 3 && len(keywords) < 10 {
			// Remove common words
			if word != "the" && word != "and" && word != "with" && word != "for" {
				keywords = append(keywords, word)
			}
		}
	}

	// Ensure we have at least 5 keywords
	defaultKeywords := []string{"creative", "digital", "content", "generated", "artistic"}
	for _, kw := range defaultKeywords {
		if len(keywords) >= 10 {
			break
		}
		keywords = append(keywords, kw)
	}

	return &models.KeywordExtractionResponse{
		Keywords: keywords[:min(10, len(keywords))],
		Category: contentType,
		Style:    "general",
		Mood:     "neutral",
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// PredictVirality predicts if content will go viral based on engagement metrics
func (v *VertexAIClient) PredictVirality(req models.ViralPredictionRequest) (*models.ViralPredictionResponse, error) {
	// Calculate weighted engagement score (as per requirements: views: 1x, likes: 2x, comments: 3x, shares: 5x, remixes: 4x)
	engagementScore := float64(req.ViewCount)*1.0 + 
		float64(req.LikeCount)*2.0 + 
		float64(req.CommentCount)*3.0 + 
		float64(req.ShareCount)*5.0 + 
		float64(req.RemixCount)*4.0

	// Calculate velocity factor (engagement per minute)
	velocityFactor := req.EngagementVelocity * 10.0

	// Time decay factor - newer content gets a boost
	timeDecay := 1.0
	if req.TimeElapsed > 0 {
		timeDecay = 1.0 / (1.0 + float64(req.TimeElapsed)/60.0) // Decay over hours
	}

	// Calculate viral score combining engagement, velocity, and time
	viralScore := (engagementScore + velocityFactor) * timeDecay

	// Calculate viral probability based on score
	// Using a sigmoid-like function to map score to probability [0, 1]
	viralProbability := 0.0
	if viralScore > 200 {
		viralProbability = 0.95
	} else if viralScore > 150 {
		viralProbability = 0.85
	} else if viralScore > 100 {
		viralProbability = 0.75
	} else if viralScore > 70 {
		viralProbability = 0.65
	} else if viralScore > 50 {
		viralProbability = 0.55
	} else if viralScore > 30 {
		viralProbability = 0.40
	} else if viralScore > 20 {
		viralProbability = 0.30
	} else if viralScore > 10 {
		viralProbability = 0.20
	} else if viralScore > 5 {
		viralProbability = 0.10
	} else {
		viralProbability = 0.05
	}

	// Boost probability if engagement velocity is very high
	if req.EngagementVelocity > 20 {
		viralProbability = min64(viralProbability*1.2, 1.0)
	} else if req.EngagementVelocity > 10 {
		viralProbability = min64(viralProbability*1.1, 1.0)
	}

	// Calculate confidence based on data availability
	confidence := 0.5 // Base confidence
	totalEngagement := req.ViewCount + req.LikeCount + req.CommentCount + req.ShareCount + req.RemixCount
	if totalEngagement > 1000 {
		confidence = 0.95
	} else if totalEngagement > 500 {
		confidence = 0.90
	} else if totalEngagement > 100 {
		confidence = 0.85
	} else if totalEngagement > 50 {
		confidence = 0.75
	} else if totalEngagement > 10 {
		confidence = 0.65
	}

	// Predict peak time based on current velocity and engagement pattern
	predictedPeakTime := 60 // default 1 hour
	if req.EngagementVelocity > 20 {
		predictedPeakTime = 15 // 15 minutes for extremely fast-growing content
	} else if req.EngagementVelocity > 10 {
		predictedPeakTime = 30 // 30 minutes for fast-growing content
	} else if req.EngagementVelocity > 5 {
		predictedPeakTime = 45 // 45 minutes for moderate growth
	} else if req.EngagementVelocity > 2 {
		predictedPeakTime = 90 // 1.5 hours for slow growth
	} else {
		predictedPeakTime = 120 // 2 hours for very slow growth
	}

	return &models.ViralPredictionResponse{
		ViralProbability:  viralProbability,
		Confidence:        confidence,
		PredictedPeakTime: predictedPeakTime,
	}, nil
}

func min64(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

// callGemini makes a request to Gemini Pro API
func (v *VertexAIClient) callGemini(systemPrompt, userPrompt string) (string, error) {
	// Get Gemini Pro model
	model := v.genaiClient.GenerativeModel("gemini-pro")
	
	// Configure model parameters
	model.Temperature = 0.2 // Lower temperature for more consistent results
	model.TopP = 0.8
	model.TopK = 40
	model.MaxOutputTokens = 1024

	// Combine system prompt and user prompt
	fullPrompt := fmt.Sprintf("%s\n\n%s", systemPrompt, userPrompt)

	// Generate content
	resp, err := model.GenerateContent(v.ctx, genai.Text(fullPrompt))
	if err != nil {
		return "", fmt.Errorf("gemini generation failed: %w", err)
	}

	// Extract text from response
	if len(resp.Candidates) == 0 {
		return "", fmt.Errorf("no candidates returned from gemini")
	}

	candidate := resp.Candidates[0]
	if candidate.Content == nil || len(candidate.Content.Parts) == 0 {
		return "", fmt.Errorf("no content in gemini response")
	}

	// Concatenate all text parts
	var result strings.Builder
	for _, part := range candidate.Content.Parts {
		if text, ok := part.(genai.Text); ok {
			result.WriteString(string(text))
		}
	}

	return result.String(), nil
}

// getFromCache retrieves a cached response if it exists and hasn't expired
func (v *VertexAIClient) getFromCache(key string) interface{} {
	v.cacheMutex.RLock()
	defer v.cacheMutex.RUnlock()

	entry, exists := v.cache[key]
	if !exists {
		return nil
	}

	// Check if expired
	if time.Now().After(entry.expiresAt) {
		return nil
	}

	return entry.response
}

// putInCache stores a response in the cache with TTL
func (v *VertexAIClient) putInCache(key string, response interface{}) {
	v.cacheMutex.Lock()
	defer v.cacheMutex.Unlock()

	v.cache[key] = &cacheEntry{
		response:  response,
		expiresAt: time.Now().Add(v.cacheTTL),
	}
}

// cleanExpiredCache removes expired entries from cache (should be called periodically)
func (v *VertexAIClient) cleanExpiredCache() {
	v.cacheMutex.Lock()
	defer v.cacheMutex.Unlock()

	now := time.Now()
	for key, entry := range v.cache {
		if now.After(entry.expiresAt) {
			delete(v.cache, key)
		}
	}
}

func (v *VertexAIClient) Close() error {
	return v.genaiClient.Close()
}
