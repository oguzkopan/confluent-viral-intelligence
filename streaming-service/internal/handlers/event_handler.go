package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/models"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/services"
)

type EventHandler struct {
	processor *services.EventProcessor
}

func NewEventHandler(processor *services.EventProcessor) *EventHandler {
	return &EventHandler{processor: processor}
}

func (h *EventHandler) HandleInteraction(c *gin.Context) {
	var event models.InteractionEvent
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set timestamp if not provided
	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now()
	}

	if err := h.processor.ProcessInteraction(event); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process interaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func (h *EventHandler) HandleContentMetadata(c *gin.Context) {
	var event models.ContentMetadata
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set timestamp if not provided
	if event.CreatedAt.IsZero() {
		event.CreatedAt = time.Now()
	}

	if err := h.processor.ProcessContentMetadata(event); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process content metadata"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":   "success",
		"keywords": event.Keywords,
		"category": event.Category,
		"style":    event.Style,
	})
}

func (h *EventHandler) HandleView(c *gin.Context) {
	var event models.ViewEvent
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set timestamp if not provided
	if event.ViewedAt.IsZero() {
		event.ViewedAt = time.Now()
	}

	if err := h.processor.ProcessView(event); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process view"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func (h *EventHandler) HandleRemix(c *gin.Context) {
	var event models.RemixEvent
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set timestamp if not provided
	if event.RemixedAt.IsZero() {
		event.RemixedAt = time.Now()
	}

	if err := h.processor.ProcessRemix(event); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process remix"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
