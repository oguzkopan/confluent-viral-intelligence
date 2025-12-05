package services

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func TestNewWebSocketHub(t *testing.T) {
	hub := NewWebSocketHub()

	if hub == nil {
		t.Fatal("Expected hub to be created, got nil")
	}

	if hub.clients == nil {
		t.Error("Expected clients map to be initialized")
	}

	if hub.broadcast == nil {
		t.Error("Expected broadcast channel to be initialized")
	}

	if hub.register == nil {
		t.Error("Expected register channel to be initialized")
	}

	if hub.unregister == nil {
		t.Error("Expected unregister channel to be initialized")
	}
}

func TestWebSocketHub_ClientRegistration(t *testing.T) {
	hub := NewWebSocketHub()
	go hub.Run()

	// Create a mock WebSocket connection
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		hub.register <- client

		// Wait a bit for registration
		time.Sleep(100 * time.Millisecond)

		// Check client count
		if hub.GetClientCount() != 1 {
			t.Errorf("Expected 1 client, got %d", hub.GetClientCount())
		}

		// Unregister client
		hub.unregister <- client
		time.Sleep(100 * time.Millisecond)

		if hub.GetClientCount() != 0 {
			t.Errorf("Expected 0 clients after unregister, got %d", hub.GetClientCount())
		}
	}))
	defer server.Close()

	// Connect to the test server
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	_, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}

	time.Sleep(200 * time.Millisecond)
}

func TestWebSocketHub_BroadcastTrendingUpdate(t *testing.T) {
	hub := NewWebSocketHub()
	go hub.Run()

	messageChan := make(chan []byte, 1)

	// Create a test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		hub.register <- client
		client.Start()

		// Keep connection alive and wait for messages
		time.Sleep(500 * time.Millisecond)
	}))
	defer server.Close()

	// Connect client
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	clientConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}
	defer clientConn.Close()

	// Start reading messages in a goroutine
	go func() {
		clientConn.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, message, err := clientConn.ReadMessage()
		if err == nil {
			messageChan <- message
		}
	}()

	// Wait for registration
	time.Sleep(100 * time.Millisecond)

	// Broadcast a trending update
	hub.BroadcastTrendingUpdate("post123", 95.5, 1000)

	// Wait for message
	select {
	case message := <-messageChan:
		// Parse the message
		var update TrendingUpdateMessage
		if err := json.Unmarshal(message, &update); err != nil {
			t.Fatalf("Failed to unmarshal message: %v", err)
		}

		// Verify message content
		if update.Type != "trending_update" {
			t.Errorf("Expected type 'trending_update', got '%s'", update.Type)
		}

		if update.PostID != "post123" {
			t.Errorf("Expected PostID 'post123', got '%s'", update.PostID)
		}

		if update.Score != 95.5 {
			t.Errorf("Expected Score 95.5, got %.2f", update.Score)
		}

		if update.ViewCount != 1000 {
			t.Errorf("Expected ViewCount 1000, got %d", update.ViewCount)
		}

		if update.Timestamp == "" {
			t.Error("Expected Timestamp to be set")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for message")
	}
}

func TestWebSocketHub_BroadcastViralAlert(t *testing.T) {
	hub := NewWebSocketHub()
	go hub.Run()

	messageChan := make(chan []byte, 1)

	// Create a test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		hub.register <- client
		client.Start()

		// Keep connection alive
		time.Sleep(500 * time.Millisecond)
	}))
	defer server.Close()

	// Connect client
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	clientConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}
	defer clientConn.Close()

	// Start reading messages in a goroutine
	go func() {
		clientConn.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, message, err := clientConn.ReadMessage()
		if err == nil {
			messageChan <- message
		}
	}()

	// Wait for registration
	time.Sleep(100 * time.Millisecond)

	// Broadcast a viral alert
	hub.BroadcastViralAlert("post456", 0.85, 120.0)

	// Wait for message
	select {
	case message := <-messageChan:
		// Parse the message
		var alert ViralAlertMessage
		if err := json.Unmarshal(message, &alert); err != nil {
			t.Fatalf("Failed to unmarshal message: %v", err)
		}

		// Verify message content
		if alert.Type != "viral_alert" {
			t.Errorf("Expected type 'viral_alert', got '%s'", alert.Type)
		}

		if alert.PostID != "post456" {
			t.Errorf("Expected PostID 'post456', got '%s'", alert.PostID)
		}

		if alert.ViralProbability != 0.85 {
			t.Errorf("Expected ViralProbability 0.85, got %.2f", alert.ViralProbability)
		}

		if alert.Score != 120.0 {
			t.Errorf("Expected Score 120.0, got %.2f", alert.Score)
		}

		if alert.Message == "" {
			t.Error("Expected Message to be set")
		}

		if alert.Timestamp == "" {
			t.Error("Expected Timestamp to be set")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for message")
	}
}

func TestWebSocketHub_MultipleClients(t *testing.T) {
	hub := NewWebSocketHub()
	go hub.Run()

	// Create a test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		hub.register <- client
		client.Start()

		// Keep connection alive
		time.Sleep(500 * time.Millisecond)
	}))
	defer server.Close()

	// Connect multiple clients
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	
	client1, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket client 1: %v", err)
	}
	defer client1.Close()

	client2, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket client 2: %v", err)
	}
	defer client2.Close()

	// Wait for registration
	time.Sleep(200 * time.Millisecond)

	// Check client count
	if hub.GetClientCount() != 2 {
		t.Errorf("Expected 2 clients, got %d", hub.GetClientCount())
	}

	// Broadcast a message
	hub.BroadcastTrendingUpdate("post789", 50.0, 500)

	// Both clients should receive the message
	client1.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, msg1, err := client1.ReadMessage()
	if err != nil {
		t.Errorf("Client 1 failed to read message: %v", err)
	}

	client2.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, msg2, err := client2.ReadMessage()
	if err != nil {
		t.Errorf("Client 2 failed to read message: %v", err)
	}

	// Verify both received the same message
	if string(msg1) != string(msg2) {
		t.Error("Clients received different messages")
	}
}

func TestNewWebSocketClient(t *testing.T) {
	hub := NewWebSocketHub()
	
	// Create a mock connection (we can't easily test this without a real connection)
	// So we'll just test that the constructor doesn't panic
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		
		if client == nil {
			t.Fatal("Expected client to be created, got nil")
		}

		if client.conn == nil {
			t.Error("Expected conn to be set")
		}

		if client.send == nil {
			t.Error("Expected send channel to be initialized")
		}

		if client.hub != hub {
			t.Error("Expected hub reference to be set")
		}
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	_, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}

	time.Sleep(100 * time.Millisecond)
}

func TestWebSocketHub_GetClientCount(t *testing.T) {
	hub := NewWebSocketHub()
	go hub.Run()

	// Initially should be 0
	if hub.GetClientCount() != 0 {
		t.Errorf("Expected 0 clients initially, got %d", hub.GetClientCount())
	}

	// Create a test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade connection: %v", err)
		}
		defer conn.Close()

		client := NewWebSocketClient(conn, hub)
		hub.register <- client

		time.Sleep(200 * time.Millisecond)
	}))
	defer server.Close()

	// Connect a client
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}
	defer conn.Close()

	time.Sleep(200 * time.Millisecond)

	// Should be 1 now
	if hub.GetClientCount() != 1 {
		t.Errorf("Expected 1 client, got %d", hub.GetClientCount())
	}
}
