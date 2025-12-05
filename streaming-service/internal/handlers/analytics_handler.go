package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"confluent-viral-intelligence/internal/services"
)

type AnalyticsHandler struct {
	firestoreClient *services.FirestoreClient
}

func NewAnalyticsHandler(firestoreClient *services.FirestoreClient) *AnalyticsHandler {
	return &AnalyticsHandler{firestoreClient: firestoreClient}
}

// GetTrending returns the top trending posts
func (h *AnalyticsHandler) GetTrending(c *gin.Context) {
	// Parse limit parameter with default value of 20
	limitStr := c.DefaultQuery("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid limit parameter. Must be between 1 and 100"})
		return
	}

	// Get trending posts from Firestore
	trendingPosts, err := h.firestoreClient.GetTrendingPosts(limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch trending posts"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"count":  len(trendingPosts),
		"data":   trendingPosts,
	})
}

// GetPostStats returns statistics for a specific post
func (h *AnalyticsHandler) GetPostStats(c *gin.Context) {
	postID := c.Param("id")
	if postID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Post ID is required"})
		return
	}

	// Get post stats from Firestore
	stats, err := h.firestoreClient.GetPostStats(postID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch post stats"})
		return
	}

	if stats == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   stats,
	})
}

// GetRecommendations returns personalized recommendations for a user
func (h *AnalyticsHandler) GetRecommendations(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Parse limit parameter with default value of 10
	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 || limit > 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid limit parameter. Must be between 1 and 50"})
		return
	}

	// Get user recommendations from Firestore
	recommendations, err := h.firestoreClient.GetUserRecommendations(userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch recommendations"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"count":  len(recommendations),
		"data":   recommendations,
	})
}
