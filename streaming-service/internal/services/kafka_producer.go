package services

import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/config"
	"github.com/yourusername/hackathon-confluent-viral-intelligence/streaming-service/internal/models"
)

type KafkaProducer struct {
	producer *kafka.Producer
	config   *config.Config
}

func NewKafkaProducer(cfg *config.Config) (*KafkaProducer, error) {
	p, err := kafka.NewProducer(&kafka.ConfigMap{
		"bootstrap.servers": cfg.ConfluentBootstrapServers,
		"security.protocol": cfg.ConfluentSecurityProtocol,
		"sasl.mechanisms":   cfg.ConfluentSASLMechanism,
		"sasl.username":     cfg.ConfluentAPIKey,
		"sasl.password":     cfg.ConfluentAPISecret,
		"acks":              "all",
		"compression.type":  "snappy",
	})

	if err != nil {
		return nil, fmt.Errorf("failed to create producer: %w", err)
	}

	// Delivery report handler
	go func() {
		for e := range p.Events() {
			switch ev := e.(type) {
			case *kafka.Message:
				if ev.TopicPartition.Error != nil {
					log.Printf("Delivery failed: %v\n", ev.TopicPartition.Error)
				} else {
					log.Printf("Delivered message to %v\n", ev.TopicPartition)
				}
			}
		}
	}()

	return &KafkaProducer{
		producer: p,
		config:   cfg,
	}, nil
}

func (kp *KafkaProducer) PublishInteraction(event models.InteractionEvent) error {
	return kp.publish(kp.config.TopicUserInteractions, event.PostID, event)
}

func (kp *KafkaProducer) PublishContentMetadata(event models.ContentMetadata) error {
	return kp.publish(kp.config.TopicContentMetadata, event.PostID, event)
}

func (kp *KafkaProducer) PublishView(event models.ViewEvent) error {
	return kp.publish(kp.config.TopicViewEvents, event.PostID, event)
}

func (kp *KafkaProducer) PublishRemix(event models.RemixEvent) error {
	return kp.publish(kp.config.TopicRemixEvents, event.OriginalPostID, event)
}

func (kp *KafkaProducer) PublishTrendingScore(score models.TrendingScore) error {
	return kp.publish(kp.config.TopicTrendingScores, score.PostID, score)
}

func (kp *KafkaProducer) PublishRecommendation(rec models.Recommendation) error {
	return kp.publish(kp.config.TopicRecommendations, rec.UserID, rec)
}

func (kp *KafkaProducer) publish(topic string, key string, value interface{}) error {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	err = kp.producer.Produce(&kafka.Message{
		TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		Key:            []byte(key),
		Value:          data,
	}, nil)

	if err != nil {
		return fmt.Errorf("failed to produce message: %w", err)
	}

	return nil
}

func (kp *KafkaProducer) Close() {
	kp.producer.Flush(15 * 1000)
	kp.producer.Close()
}
