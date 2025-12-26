package config

import (
	"os"
	"strings"
)

type Config struct {
	// Confluent
	ConfluentBootstrapServers string
	ConfluentAPIKey           string
	ConfluentAPISecret        string
	ConfluentSecurityProtocol string
	ConfluentSASLMechanism    string

	// Google Cloud
	GoogleCloudProject string
	VertexAILocation   string
	VertexAIEndpointID string

	// Firestore
	FirestoreProjectID string

	// Server
	Port           string
	Environment    string
	AllowedOrigins []string

	// Kafka Topics
	TopicUserInteractions string
	TopicContentMetadata  string
	TopicTrendingScores   string
	TopicRecommendations  string
	TopicViewEvents       string
	TopicRemixEvents      string
}

func Load() *Config {
	return &Config{
		// Confluent
		ConfluentBootstrapServers: getEnv("CONFLUENT_BOOTSTRAP_SERVERS", ""),
		ConfluentAPIKey:           getEnv("CONFLUENT_API_KEY", ""),
		ConfluentAPISecret:        getEnv("CONFLUENT_API_SECRET", ""),
		ConfluentSecurityProtocol: getEnv("CONFLUENT_SECURITY_PROTOCOL", "SASL_SSL"),
		ConfluentSASLMechanism:    getEnv("CONFLUENT_SASL_MECHANISM", "PLAIN"),

		// Google Cloud
		GoogleCloudProject: getEnv("GOOGLE_CLOUD_PROJECT", "yarimai"),
		VertexAILocation:   getEnv("VERTEX_AI_LOCATION", "us-central1"),
		VertexAIEndpointID: getEnv("VERTEX_AI_ENDPOINT_ID", ""),

		// Firestore
		FirestoreProjectID: getEnv("FIRESTORE_PROJECT_ID", "yarimai"),

		// Server
		Port:           getEnv("PORT", "8080"),
		Environment:    getEnv("ENVIRONMENT", "development"),
		AllowedOrigins: parseAllowedOrigins(getEnv("ALLOWED_ORIGINS", "*")),

		// Kafka Topics
		TopicUserInteractions: getEnv("TOPIC_USER_INTERACTIONS", "user-interactions"),
		TopicContentMetadata:  getEnv("TOPIC_CONTENT_METADATA", "content-metadata"),
		TopicTrendingScores:   getEnv("TOPIC_TRENDING_SCORES", "trending-scores"),
		TopicRecommendations:  getEnv("TOPIC_RECOMMENDATIONS", "recommendations"),
		TopicViewEvents:       getEnv("TOPIC_VIEW_EVENTS", "view-events"),
		TopicRemixEvents:      getEnv("TOPIC_REMIX_EVENTS", "remix-events"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// parseAllowedOrigins parses ALLOWED_ORIGINS supporting both comma and semicolon separators
func parseAllowedOrigins(origins string) []string {
	// Support both comma and semicolon as separators
	// Replace semicolons with commas first
	origins = strings.ReplaceAll(origins, ";", ",")
	
	// Split by comma
	parts := strings.Split(origins, ",")
	
	// Trim whitespace from each origin
	result := make([]string, 0, len(parts))
	for _, origin := range parts {
		trimmed := strings.TrimSpace(origin)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	
	return result
}
