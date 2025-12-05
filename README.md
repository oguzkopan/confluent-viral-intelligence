# Real-Time Viral Content Intelligence System

**Google Cloud x Confluent Hackathon Submission**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/Go-1.24-blue.svg)](https://golang.org/)
[![Confluent Cloud](https://img.shields.io/badge/Confluent-Cloud-blue.svg)](https://confluent.cloud/)
[![Google Cloud](https://img.shields.io/badge/Google-Cloud-red.svg)](https://cloud.google.com/)

## 🎯 Project Overview

A real-time streaming intelligence system that predicts viral content and provides personalized recommendations using Confluent Cloud and Google Cloud Vertex AI. The system processes millions of user interactions per day to identify trending content before it peaks, helping creators maximize their reach and users discover the best content faster.

## 🏆 Challenge: Confluent Challenge

**Problem Solved:** Traditional social platforms analyze content engagement in batch mode (hourly/daily), missing the critical early signals of viral content. Our system processes engagement data in real-time to:

1. **Predict viral content** before it peaks using ML models (70%+ accuracy)
2. **Provide personalized recommendations** based on live trending data
3. **Auto-categorize content** with AI-generated keywords (5-10 per post)
4. **Track remix chains** to boost virality scores (4x multiplier per remix)
5. **Real-time view counting** across mobile and web platforms (sub-second latency)

## ⚡ Quick Setup

**Service Status**: ✅ Deployed to Cloud Run | ⏳ Needs Confluent credentials

### For Confluent Cloud Setup:

**Start here**: Read `CONFLUENT_SETUP_SUMMARY.md` for a complete guide

**Quick path**:
1. Get your Confluent Cloud credentials (see `CONFLUENT_QUICK_START.md`)
2. Run: `./update-confluent-credentials.sh`
3. Verify: `gcloud run logs tail viral-intelligence-streaming --region us-central1`

**Available guides**:
- 📘 `CONFLUENT_SETUP_SUMMARY.md` - Overview of all guides
- 🚀 `CONFLUENT_QUICK_START.md` - 10-minute setup guide
- 🔍 `WHERE_TO_FIND_CREDENTIALS.md` - Visual guide with screenshots
- 📝 `FIND_CONFLUENT_CREDENTIALS.md` - Quick credential reference
- 📚 `CONFLUENT_SETUP_GUIDE.md` - Complete detailed guide

**Helper script**: `update-confluent-credentials.sh` - Easy credential update

---

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

### Prerequisites

- **Confluent Cloud Account** with API access
- **Google Cloud Project** with billing enabled
- **Go 1.24+** installed
- **Node.js 18+** and npm installed
- **Firebase CLI** installed (`npm install -g firebase-tools`)
- **gcloud CLI** installed and authenticated

### Quick Start (5 minutes)

```bash
# 1. Clone and navigate to project
cd hackathon-confluent-viral-intelligence

# 2. Set up Confluent Cloud infrastructure
./confluent-setup.sh

# 3. Verify Confluent setup
./verify-confluent-setup.sh

# 4. Configure environment variables
cd streaming-service
cp .env.example .env
# Edit .env with your credentials

# 5. Deploy streaming service
./deploy.sh

# 6. Deploy dashboard
cd ../dashboard
npm install
npm run build
firebase deploy

# 7. Run end-to-end tests
cd ..
./e2e-test.sh
```

### Detailed Setup

For step-by-step instructions, see:
- [**Quick Setup Guide**](./QUICK_SETUP.md) - Get started in 5 minutes
- [**Complete Setup Guide**](./SETUP.md) - Full installation and configuration
- [**Confluent Setup Guide**](./CONFLUENT_SETUP_GUIDE.md) - Confluent Cloud configuration
- [**Integration Guide**](./INTEGRATION_GUIDE.md) - Integrate with existing platforms

## 📚 Documentation

**📋 [Complete Documentation Index](./DOCUMENTATION_INDEX.md)** - Navigate all documentation

### Getting Started
- [Quick Setup](./QUICK_SETUP.md) - Fast track setup
- [Setup Guide](./SETUP.md) - Complete installation
- [Quick Reference](./QUICK_REFERENCE.md) - Common commands and URLs

### Architecture & Design
- [Architecture Overview](./ARCHITECTURE.md) - System design and data flow
- [Topic Configurations](./TOPIC_CONFIGURATIONS.md) - Kafka topic schemas
- [File Structure](./FILE_STRUCTURE.md) - Project organization

**Architecture Diagrams:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Client Applications                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   iOS App    │  │   Web App    │  │  Dashboard   │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
└─────────┼──────────────────┼─────────────────┼──────────────────┘
          │                  │                 │
          │  HTTP/REST       │                 │  WebSocket
          └──────────────────┴─────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Streaming Service (Go on Cloud Run)                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Event Ingestion API + Kafka Producer + WebSocket      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Confluent Cloud                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Kafka Topics → Flink SQL Processing → Aggregations     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                         │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │   Vertex AI      │  │   Firestore      │                    │
│  │  (Gemini + ML)   │  │  (yarimai)       │                    │
│  └──────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed diagrams and data flow.

### Deployment
- [Deployment Guide](./PRODUCTION_DEPLOYMENT_GUIDE.md) - Production deployment
- [Deployment Quick Reference](./DEPLOYMENT_QUICK_REFERENCE.md) - Common deployment tasks

### Integration
- [Integration Guide](./INTEGRATION_GUIDE.md) - Platform integration steps
- [API Documentation](./API_DOCUMENTATION.md) - REST API reference
- [Environment Variables](./ENVIRONMENT_VARIABLES.md) - Configuration reference

### Testing
- [E2E Testing Guide](./E2E_TESTING_GUIDE.md) - End-to-end testing
- [Testing Workflow](./TESTING_WORKFLOW.md) - Testing procedures
- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Common issues and solutions

### Component Documentation
- [Streaming Service](./streaming-service/README.md) - Go microservice
- [Dashboard](./dashboard/README.md) - React dashboard
- [Flink SQL](./flink-sql/README.md) - Stream processing

## 🆘 Troubleshooting

See the [Troubleshooting Guide](./TROUBLESHOOTING.md) for common issues and solutions.

Quick fixes:
- **Kafka connection issues:** Check bootstrap server URL and API credentials
- **Flink jobs not running:** Verify compute pool is active
- **Dashboard not updating:** Check WebSocket connection status
- **Deployment failures:** Verify GCP permissions and quotas

## 🤝 Contributing

This is a hackathon project. For questions or issues, please open a GitHub issue.

## 📝 License

MIT License - Open Source

---

**Built with ❤️ for the Google Cloud x Confluent Hackathon**
