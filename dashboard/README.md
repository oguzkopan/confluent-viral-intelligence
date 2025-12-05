# Viral Intelligence Dashboard

Real-time dashboard for monitoring trending content and viral predictions powered by Confluent Cloud and Google Cloud Vertex AI.

## Features

✅ **Real-Time Updates** - WebSocket connection for live data streaming
✅ **Trending Feed** - Top 20 trending posts with engagement metrics
✅ **Viral Predictions** - AI-powered viral probability predictions
✅ **Live Metrics** - Total views, interactions, and viral post count
✅ **Viral Alerts** - Real-time notifications when content goes viral

## Components

### TrendingFeed
Displays the top trending posts with:
- Ranking position
- View, like, comment, share, and remix counts
- Trending score and engagement velocity
- Viral probability percentage

### ViralPredictions
Shows posts with high viral potential:
- Viral probability percentage with color coding
- Visual probability bar
- Engagement velocity and total engagement
- "GOING VIRAL" badge for posts >70% probability

### RealTimeMetrics
Dashboard metrics cards showing:
- Total views across all trending posts
- Total interactions (likes + comments + shares)
- Number of posts with viral probability >70%

### WebSocketStatus
Connection indicator showing:
- Live connection status
- Animated pulse indicator
- "Live Updates Active" or "Connecting..." status

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file from `.env.example`:
```bash
cp .env.example .env
```

3. Update environment variables in `.env`:
```
REACT_APP_API_URL=http://localhost:8080
REACT_APP_WS_URL=ws://localhost:8080/ws
```

## Development

Start the development server:
```bash
npm start
```

The dashboard will open at http://localhost:3000

## Production Build

Build for production:
```bash
npm run build
```

The optimized build will be in the `build/` directory.

## Deployment

Deploy to Firebase Hosting:
```bash
npm run build
firebase deploy --only hosting
```

## API Integration

The dashboard connects to the Streaming Service API:

### REST Endpoints
- `GET /api/analytics/trending?limit=20` - Fetch trending posts

### WebSocket
- `ws://[host]/ws` - Real-time updates
  - Message type: `trending_update` - Updated trending score
  - Message type: `viral_alert` - Viral probability alert

## Requirements Validation

✅ **Requirement 7.1** - WebSocket connection established within 1 second
✅ **Requirement 7.2** - Real-time updates pushed via WebSocket within 1 second
✅ **Requirement 7.3** - Top 20 posts displayed ranked by trending score
✅ **Requirement 7.4** - All metrics displayed (views, likes, comments, shares, remixes, viral probability)
✅ **Requirement 7.5** - Real-time viral alert notifications

## Technology Stack

- **React 18** - UI framework
- **Chart.js** - Data visualization (available for future enhancements)
- **Axios** - HTTP client (available for API calls)
- **WebSocket API** - Real-time communication
- **CSS3** - Styling with gradients and animations

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
