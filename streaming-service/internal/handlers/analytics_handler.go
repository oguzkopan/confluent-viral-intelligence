package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/services"
)

type AnalyticsHandler struct {
	processor *services.EventProcessor
}

func NewAnalyticsHandler(processor *services.EventProcessor) *AnalyticsHandler {
	return &AnalyticsHandler{processor: processor}
}

func (h *AnalyticsHandler) GetTrending(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 20
	}

	posts, err := h.processor.GetTrendingPosts(limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch trending posts"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"trending": posts,
		"count":    len(posts),
	})
}

func (h *AnalyticsHandler) GetPostStats(c *gin.Context) {
	postID := c.Param("id")
	if postID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Post ID is required"})
		return
	}

	stats, err := h.processor.GetPostStats(postID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post stats not found"})
		return
	}

	c.JSON(http.StatusOK, stats)
}

func (h *AnalyticsHandler) GetRecommendations(c *gin.Context) {
	userID := c.Param("id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 10
	}

	recommendations, err := h.processor.GetUserRecommendations(userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch recommendations"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"recommendations": recommendations,
		"count":           len(recommendations),
	})
}
