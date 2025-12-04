package services

import (
	"context"
	"encoding/json"
	"log"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/config"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/models"
)

type KafkaConsumer struct {
	consumer  *kafka.Consumer
	config    *config.Config
	processor *EventProcessor
}

func NewKafkaConsumer(cfg *config.Config, processor *EventProcessor) (*KafkaConsumer, error) {
	c, err := kafka.NewConsumer(&kafka.ConfigMap{
		"bootstrap.servers": cfg.ConfluentBootstrapServers,
		"security.protocol": cfg.ConfluentSecurityProtocol,
		"sasl.mechanisms":   cfg.ConfluentSASLMechanism,
		"sasl.username":     cfg.ConfluentAPIKey,
		"sasl.password":     cfg.ConfluentAPISecret,
		"group.id":          "viral-intelligence-consumer",
		"auto.offset.reset": "earliest",
	})

	if err != nil {
		return nil, err
	}

	return &KafkaConsumer{
		consumer:  c,
		config:    cfg,
		processor: processor,
	}, nil
}

func (kc *KafkaConsumer) Start(ctx context.Context) {
	topics := []string{
		kc.config.TopicTrendingScores,
		kc.config.TopicRecommendations,
	}

	err := kc.consumer.SubscribeTopics(topics, nil)
	if err != nil {
		log.Fatalf("Failed to subscribe to topics: %v", err)
	}

	log.Printf("Consumer started, subscribed to: %v", topics)

	for {
		select {
		case <-ctx.Done():
			log.Println("Consumer shutting down")
			return
		default:
			msg, err := kc.consumer.ReadMessage(-1)
			if err != nil {
				log.Printf("Consumer error: %v", err)
				continue
			}

			kc.processMessage(msg)
		}
	}
}

func (kc *KafkaConsumer) processMessage(msg *kafka.Message) {
	topic := *msg.TopicPartition.Topic

	switch topic {
	case kc.config.TopicTrendingScores:
		var score models.TrendingScore
		if err := json.Unmarshal(msg.Value, &score); err != nil {
			log.Printf("Failed to unmarshal trending score: %v", err)
			return
		}
		kc.processor.ProcessTrendingScore(score)

	case kc.config.TopicRecommendations:
		var rec models.Recommendation
		if err := json.Unmarshal(msg.Value, &rec); err != nil {
			log.Printf("Failed to unmarshal recommendation: %v", err)
			return
		}
		kc.processor.ProcessRecommendation(rec)
	}
}

func (kc *KafkaConsumer) Close() {
	kc.consumer.Close()
}
