package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"confluent-viral-intelligence/internal/config"
	"confluent-viral-intelligence/internal/models"
)

type KafkaConsumer struct {
	consumer       *kafka.Consumer
	config         *config.Config
	eventProcessor *EventProcessor
	ctx            context.Context
	cancel         context.CancelFunc
}

func NewKafkaConsumer(cfg *config.Config, eventProcessor *EventProcessor) (*KafkaConsumer, error) {
	c, err := kafka.NewConsumer(&kafka.ConfigMap{
		"bootstrap.servers":  cfg.ConfluentBootstrapServers,
		"security.protocol":  cfg.ConfluentSecurityProtocol,
		"sasl.mechanisms":    cfg.ConfluentSASLMechanism,
		"sasl.username":      cfg.ConfluentAPIKey,
		"sasl.password":      cfg.ConfluentAPISecret,
		"group.id":           "viral-intelligence-consumer",
		"auto.offset.reset":  "earliest",
		"enable.auto.commit": true,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to create consumer: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &KafkaConsumer{
		consumer:       c,
		config:         cfg,
		eventProcessor: eventProcessor,
		ctx:            ctx,
		cancel:         cancel,
	}, nil
}

// Start begins consuming messages from subscribed topics
func (kc *KafkaConsumer) Start() error {
	// Subscribe to trending-scores and recommendations topics
	topics := []string{
		kc.config.TopicTrendingScores,
		kc.config.TopicRecommendations,
	}

	err := kc.consumer.SubscribeTopics(topics, nil)
	if err != nil {
		return fmt.Errorf("failed to subscribe to topics: %w", err)
	}

	log.Printf("Kafka consumer subscribed to topics: %v", topics)

	// Start message processing loop
	go kc.processMessages()

	return nil
}

// processMessages is the main message processing loop
func (kc *KafkaConsumer) processMessages() {
	log.Println("Starting Kafka consumer message processing loop")

	for {
		select {
		case <-kc.ctx.Done():
			log.Println("Kafka consumer shutting down")
			return
		default:
			msg, err := kc.consumer.ReadMessage(100 * time.Millisecond)
			if err != nil {
				// Timeout is expected, continue
				if err.(kafka.Error).Code() == kafka.ErrTimedOut {
					continue
				}
				log.Printf("Consumer error: %v", err)
				continue
			}

			// Process the message
			if err := kc.handleMessage(msg); err != nil {
				log.Printf("Failed to handle message from topic %s: %v", *msg.TopicPartition.Topic, err)
			}
		}
	}
}

// handleMessage processes a single Kafka message
func (kc *KafkaConsumer) handleMessage(msg *kafka.Message) error {
	topic := *msg.TopicPartition.Topic
	
	log.Printf("Received message from topic %s, partition %d, offset %d",
		topic, msg.TopicPartition.Partition, msg.TopicPartition.Offset)

	switch topic {
	case kc.config.TopicTrendingScores:
		return kc.handleTrendingScore(msg.Value)
	case kc.config.TopicRecommendations:
		return kc.handleRecommendation(msg.Value)
	default:
		log.Printf("Unknown topic: %s", topic)
		return nil
	}
}

// handleTrendingScore deserializes and processes a trending score message
func (kc *KafkaConsumer) handleTrendingScore(data []byte) error {
	var score models.TrendingScore
	if err := json.Unmarshal(data, &score); err != nil {
		return fmt.Errorf("failed to unmarshal trending score: %w", err)
	}

	// Pass to event processor
	kc.eventProcessor.ProcessTrendingScore(score)
	
	return nil
}

// handleRecommendation deserializes and processes a recommendation message
func (kc *KafkaConsumer) handleRecommendation(data []byte) error {
	var rec models.Recommendation
	if err := json.Unmarshal(data, &rec); err != nil {
		return fmt.Errorf("failed to unmarshal recommendation: %w", err)
	}

	// Pass to event processor
	kc.eventProcessor.ProcessRecommendation(rec)
	
	return nil
}

// Close gracefully shuts down the consumer
func (kc *KafkaConsumer) Close() error {
	log.Println("Closing Kafka consumer")
	kc.cancel()
	return kc.consumer.Close()
}
