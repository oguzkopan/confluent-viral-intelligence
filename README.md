# Real-Time Viral Content Intelligence System

**Google Cloud x Confluent Hackathon Submission**

## 🎯 Project Overview

A real-time streaming intelligence system that predicts viral content and provides personalized recommendations using Confluent Cloud and Google Cloud Vertex AI.

## 🏆 Challenge: Confluent Challenge

**Problem Solved:** Traditional social platforms analyze content engagement in batch mode (hourly/daily), missing the critical early signals of viral content. Our system processes engagement data in real-time to:

1. **Predict viral content** before it peaks using ML models
2. **Provide personalized recommendations** based on live trending data
3. **Auto-categorize content** with AI-generated keywords
4. **Track remix chains** to boost virality scores
5. **Real-time view counting** across mobile and web platforms

## 🚀 Key Features

### 1. Real-Time Viral Detection
- Streams all user interactions (views, likes, comments, shares, remixes) to Confluent
- Calculates engagement velocity using Flink SQL
- Predicts viral probability with Vertex AI
- Triggers notifications when content is trending

### 2. Personalized Content Recommendations
- Analyzes user behavior patterns in real-time
- Generates personalized prompt suggestions
- Recommends trending styles and voices
- "Users like you are creating..." feature

### 3. AI-Powered Content Categorization
- Auto-generates keywords using Vertex AI Gemini
- Enables semantic search and content discovery
- Categorizes by style, mood, theme, and technique

### 4. Remix Virality Tracking
- Tracks remix chains and attribution
- Boosts virality scores for remixed content
- Identifies remix trends in real-time

### 5. Real-Time Analytics Dashboard
- Live trending content feed
- Engagement velocity charts
- Viral prediction confidence scores
- Creator analytics and insights

## 🏗️ Architecture

```
Mobile/Web Apps → Event Streaming Service (Go) → Confluent Cloud
                                                        ↓
                                                  Kafka Topics
                                                        ↓
                                    ┌──────────────────┼──────────────────┐
                                    ↓                  ↓                  ↓
                            Flink Processing    Vertex AI ML      Real-time Dashboard
                            (Aggregations)      (Predictions)      (WebSocket Updates)
                                    ↓                  ↓                  ↓
                            Trending Scores → Firestore ← Recommendations
```

## 🛠️ Technology Stack

### Confluent Cloud
- **Kafka Topics:** user-interactions, content-metadata, trending-scores, recommendations
- **Flink SQL:** Real-time aggregations and windowing
- **Connectors:** Firestore sink connector

### Google Cloud
- **Vertex AI:** Gemini for keyword generation, custom models for viral prediction
- **Cloud Run:** Microservices deployment
- **Firestore:** Real-time database
- **Cloud Storage:** Model artifacts

### Backend
- **Go:** High-performance event streaming service
- **Kafka Go Client:** confluent-kafka-go
- **REST API:** Event ingestion endpoints

### Frontend
- **React Dashboard:** Real-time analytics visualization
- **WebSocket:** Live updates
- **Chart.js:** Data visualization

## 📊 Data Flow

1. **Event Capture:** User interactions captured from mobile (Swift) and web (React)
2. **Event Streaming:** Go service publishes events to Confluent Kafka topics
3. **Real-time Processing:** Flink SQL aggregates engagement metrics in 1-minute windows
4. **AI Analysis:** Vertex AI models predict virality and generate recommendations
5. **Action Triggers:** Push notifications, feed updates, analytics refresh
6. **Dashboard Updates:** WebSocket pushes live data to React dashboard

## 🎬 Demo Video Highlights

1. User creates content → Real-time event streaming
2. Dashboard shows live engagement metrics
3. Viral prediction score increases in real-time
4. Content appears in "Trending Now" feed
5. Other users receive personalized recommendations
6. Remix chain tracking and virality boost
7. AI-generated keywords for content categorization

## 📈 Impact

- **Creators:** Get notified when content is trending, optimize posting strategy
- **Users:** Discover trending content faster, personalized recommendations
- **Platform:** Increased engagement, better content discovery, viral amplification

## 🔧 Setup Instructions

See [SETUP.md](./SETUP.md) for detailed installation and deployment instructions.

## 📝 License

MIT License - Open Source
