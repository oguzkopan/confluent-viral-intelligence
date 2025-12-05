package services

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocketHub manages all active WebSocket connections
type WebSocketHub struct {
	// Registered clients
	clients map[*WebSocketClient]bool

	// Inbound messages from clients
	broadcast chan []byte

	// Register requests from clients
	register chan *WebSocketClient

	// Unregister requests from clients
	unregister chan *WebSocketClient

	// Mutex for thread-safe operations
	mu sync.RWMutex
}

// WebSocketClient represents a single WebSocket connection
type WebSocketClient struct {
	// The WebSocket connection
	conn *websocket.Conn

	// Buffered channel of outbound messages
	send chan []byte

	// Reference to the hub
	hub *WebSocketHub
}

// TrendingUpdateMessage represents a trending score update
type TrendingUpdateMessage struct {
	Type      string  `json:"type"`
	PostID    string  `json:"post_id"`
	Score     float64 `json:"score"`
	ViewCount int64   `json:"view_count"`
	Timestamp string  `json:"timestamp"`
}

// ViralAlertMessage represents a viral alert notification
type ViralAlertMessage struct {
	Type             string  `json:"type"`
	PostID           string  `json:"post_id"`
	ViralProbability float64 `json:"viral_probability"`
	Score            float64 `json:"score"`
	Message          string  `json:"message"`
	Timestamp        string  `json:"timestamp"`
}

const (
	// Time allowed to write a message to the peer
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer
	pongWait = 60 * time.Second

	// Send pings to peer with this period (must be less than pongWait)
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer
	maxMessageSize = 512

	// Buffer size for client send channel
	sendBufferSize = 256
)

// NewWebSocketHub creates a new WebSocket hub
func NewWebSocketHub() *WebSocketHub {
	return &WebSocketHub{
		clients:    make(map[*WebSocketClient]bool),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *WebSocketClient),
		unregister: make(chan *WebSocketClient),
	}
}

// Run starts the WebSocket hub's main loop
func (h *WebSocketHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("WebSocket client registered. Total clients: %d", len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				log.Printf("WebSocket client unregistered. Total clients: %d", len(h.clients))
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
					// Message sent successfully
				default:
					// Client's send buffer is full, close the connection
					h.mu.RUnlock()
					h.mu.Lock()
					close(client.send)
					delete(h.clients, client)
					h.mu.Unlock()
					h.mu.RLock()
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastTrendingUpdate sends a trending score update to all connected clients
func (h *WebSocketHub) BroadcastTrendingUpdate(postID string, score float64, viewCount int64) {
	message := TrendingUpdateMessage{
		Type:      "trending_update",
		PostID:    postID,
		Score:     score,
		ViewCount: viewCount,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling trending update: %v", err)
		return
	}

	h.broadcast <- data
	log.Printf("Broadcasted trending update for post %s (score: %.2f)", postID, score)
}

// BroadcastViralAlert sends a viral alert to all connected clients
func (h *WebSocketHub) BroadcastViralAlert(postID string, viralProbability, score float64) {
	message := ViralAlertMessage{
		Type:             "viral_alert",
		PostID:           postID,
		ViralProbability: viralProbability,
		Score:            score,
		Message:          "Content is predicted to go viral!",
		Timestamp:        time.Now().UTC().Format(time.RFC3339),
	}

	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling viral alert: %v", err)
		return
	}

	h.broadcast <- data
	log.Printf("Broadcasted viral alert for post %s (probability: %.2f%%)", postID, viralProbability*100)
}

// GetClientCount returns the number of connected clients
func (h *WebSocketHub) GetClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// RegisterClient registers a new client with the hub
func (h *WebSocketHub) RegisterClient(client *WebSocketClient) {
	h.register <- client
}

// NewWebSocketClient creates a new WebSocket client
func NewWebSocketClient(conn *websocket.Conn, hub *WebSocketHub) *WebSocketClient {
	return &WebSocketClient{
		conn: conn,
		send: make(chan []byte, sendBufferSize),
		hub:  hub,
	}
}

// readPump pumps messages from the WebSocket connection to the hub
func (c *WebSocketClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Log received message (for debugging)
		log.Printf("Received message from client: %s", message)
	}
}

// writePump pumps messages from the hub to the WebSocket connection
func (c *WebSocketClient) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued messages to the current WebSocket message
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// Start begins the client's read and write pumps
func (c *WebSocketClient) Start() {
	go c.writePump()
	go c.readPump()
}
