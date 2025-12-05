package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"confluent-viral-intelligence/internal/services"
)

type WebSocketHandler struct {
	hub      *services.WebSocketHub
	upgrader websocket.Upgrader
}

func NewWebSocketHandler(hub *services.WebSocketHub) *WebSocketHandler {
	return &WebSocketHandler{
		hub: hub,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			// Allow all origins for WebSocket connections
			// In production, you should restrict this to specific origins
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}
}

// HandleWebSocket upgrades HTTP connection to WebSocket and registers the client
func (h *WebSocketHandler) HandleWebSocket(c *gin.Context) {
	// Upgrade HTTP connection to WebSocket
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection to WebSocket: %v", err)
		return
	}

	// Create a new WebSocket client
	client := services.NewWebSocketClient(conn, h.hub)

	// Register the client with the hub
	h.hub.RegisterClient(client)

	// Start the client's read and write pumps
	client.Start()

	log.Printf("WebSocket client connected from %s", c.Request.RemoteAddr)
}
