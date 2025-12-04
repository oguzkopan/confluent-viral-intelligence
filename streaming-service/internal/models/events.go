package models

import "time"

// InteractionEvent represents a user interaction with content
type InteractionEvent struct {
	PostID    string    `json:"post_id"`
	UserID    string    `json:"user_id"`
	EventType string    `json:"event_type"` // view, like, comment, share
	Timestamp time.Time `json:"timestamp"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

// ContentMetadata represents content information
type ContentMetadata struct {
	PostID      string    `json:"post_id"`
	UserID      string    `json:"user_id"`
	ContentType string    `json:"content_type"` // image, video, music, voice
	Prompt      string    `json:"prompt"`
	CreatedAt   time.Time `json:"created_at"`
	Keywords    []string  `json:"keywords,omitempty"`
	Category    string    `json:"category,omitempty"`
	Style       string    `json:"style,omitempty"`
}

// ViewEvent represents a content view
type ViewEvent struct {
	PostID     string    `json:"post_id"`
	UserID     string    `json:"user_id"`
	ViewedAt   time.Time `json:"viewed_at"`
	Duration   int       `json:"duration"` // seconds
	Platform   string    `json:"platform"` // mobile, web
	DeviceType string    `json:"device_type,omitempty"`
}

// RemixEvent represents a content remix
type RemixEvent struct {
	OriginalPostID string    `json:"original_post_id"`
	RemixPostID    string    `json:"remix_post_id"`
	UserID         string    `json:"user_id"`
	RemixedAt      time.Time `json:"remixed_at"`
	RemixType      string    `json:"remix_type"` // style_transfer, variation, etc.
}

// TrendingScore represents calculated trending metrics
type TrendingScore struct {
	PostID            string    `json:"post_id"`
	Score             float64   `json:"score"`
	ViralProbability  float64   `json:"viral_probability"`
	EngagementRate    float64   `json:"engagement_rate"`
	ViewCount         int64     `json:"view_count"`
	LikeCount         int64     `json:"like_count"`
	CommentCount      int64     `json:"comment_count"`
	ShareCount        int64     `json:"share_count"`
	RemixCount        int64     `json:"remix_count"`
	EngagementVelocity float64  `json:"engagement_velocity"` // interactions per minute
	CalculatedAt      time.Time `json:"calculated_at"`
	TimeWindow        string    `json:"time_window"` // 1min, 5min, 1hour
}

// Recommendation represents a personalized content recommendation
type Recommendation struct {
	UserID       string    `json:"user_id"`
	PostID       string    `json:"post_id"`
	Score        float64   `json:"score"`
	Reason       string    `json:"reason"`
	Category     string    `json:"category"`
	GeneratedAt  time.Time `json:"generated_at"`
}

// KeywordExtractionRequest for Vertex AI
type KeywordExtractionRequest struct {
	Prompt      string `json:"prompt"`
	ContentType string `json:"content_type"`
}

// KeywordExtractionResponse from Vertex AI
type KeywordExtractionResponse struct {
	Keywords []string `json:"keywords"`
	Category string   `json:"category"`
	Style    string   `json:"style"`
	Mood     string   `json:"mood"`
}

// ViralPredictionRequest for Vertex AI
type ViralPredictionRequest struct {
	PostID             string  `json:"post_id"`
	ViewCount          int64   `json:"view_count"`
	LikeCount          int64   `json:"like_count"`
	CommentCount       int64   `json:"comment_count"`
	ShareCount         int64   `json:"share_count"`
	RemixCount         int64   `json:"remix_count"`
	EngagementVelocity float64 `json:"engagement_velocity"`
	TimeElapsed        int     `json:"time_elapsed"` // minutes since creation
	ContentType        string  `json:"content_type"`
}

// ViralPredictionResponse from Vertex AI
type ViralPredictionResponse struct {
	ViralProbability float64 `json:"viral_probability"`
	Confidence       float64 `json:"confidence"`
	PredictedPeakTime int    `json:"predicted_peak_time"` // minutes from now
}
