package handlers

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/services"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for demo
	},
}

func HandleWebSocket(hub *services.WebSocketHub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}

	client := &services.WebSocketClient{
		Hub:  hub,
		Conn: conn,
		Send: make(chan []byte, 256),
	}

	hub.Register <- client

	go client.WritePump()
	go client.ReadPump()
}
