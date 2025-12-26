import React, { useState, useEffect } from 'react';
import './App.css';
import PostCard from './components/PostCard';
import MasonryGrid from './components/MasonryGrid';
import RealTimeMetrics from './components/RealTimeMetrics';
import WebSocketStatus from './components/WebSocketStatus';
import { enrichTrendingPosts } from './services/firebase';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';
const WS_URL = process.env.REACT_APP_WS_URL || 'ws://localhost:8080/ws';

function App() {
  const [trendingPosts, setTrendingPosts] = useState([]);
  const [viralAlerts, setViralAlerts] = useState([]);
  const [wsConnected, setWsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [metrics, setMetrics] = useState({
    totalViews: 0,
    totalInteractions: 0,
    viralPosts: 0
  });

  // WebSocket connection
  useEffect(() => {
    const ws = new WebSocket(WS_URL);

    ws.onopen = () => {
      console.log('WebSocket connected');
      setWsConnected(true);
    };

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      
      if (message.type === 'trending_update') {
        setTrendingPosts(prev => {
          const updated = [...prev];
          const index = updated.findIndex(p => p.post_id === message.data.post_id);
          if (index >= 0) {
            updated[index] = message.data;
          } else {
            updated.unshift(message.data);
          }
          return updated.slice(0, 20);
        });
      } else if (message.type === 'viral_alert') {
        setViralAlerts(prev => [message.data, ...prev].slice(0, 10));
        console.log('🔥 VIRAL ALERT:', message.data);
      }
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected');
      setWsConnected(false);
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    return () => ws.close();
  }, []);

  // Fetch initial trending data
  useEffect(() => {
    fetchTrending();
    const interval = setInterval(fetchTrending, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, []);

  const fetchTrending = async () => {
    try {
      setIsLoading(true);
      const response = await fetch(`${API_URL}/api/analytics/trending?limit=20`);
      const data = await response.json();
      const trending = data.data || data.trending || [];
      
      console.log('📊 Fetched trending data:', trending.length, 'posts');
      
      // Enrich with full Firestore data (rules now allow public read)
      const enrichedPosts = await enrichTrendingPosts(trending);
      console.log('✨ Enriched posts:', enrichedPosts.length, 'posts with full data');
      
      setTrendingPosts(enrichedPosts);
      
      // Update metrics
      const viralCount = enrichedPosts.filter(p => p.viral_probability > 0.7).length;
      setMetrics({
        totalViews: enrichedPosts.reduce((sum, p) => sum + (p.viewCount || p.view_count || 0), 0),
        totalInteractions: enrichedPosts.reduce((sum, p) => 
          sum + (p.likeCount || p.like_count || 0) + (p.commentCount || p.comment_count || 0) + (p.shareCount || p.share_count || 0), 0),
        viralPosts: viralCount
      });
    } catch (error) {
      console.error('Failed to fetch trending:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <div className="header-content">
          <div className="header-title">
            <h1>🔥 Viral Intelligence Dashboard</h1>
            <p>Real-time trending content powered by Confluent Cloud + Vertex AI</p>
          </div>
          <WebSocketStatus connected={wsConnected} />
        </div>
      </header>

      <main className="App-main">
        <RealTimeMetrics metrics={metrics} />

        {viralAlerts.length > 0 && (
          <div className="viral-alerts">
            <h2>🔔 Recent Viral Alerts</h2>
            <div className="alerts-grid">
              {viralAlerts.map((alert, index) => (
                <div key={index} className="viral-alert">
                  <span className="alert-icon">🚀</span>
                  <div className="alert-content">
                    <div className="alert-title">Post Going Viral!</div>
                    <div className="alert-text">
                      {(alert.probability * 100).toFixed(0)}% viral probability
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="trending-section">
          <div className="section-header">
            <h2>📈 Trending Now</h2>
            <p className="section-subtitle">
              {trendingPosts.length} posts • Updated in real-time
            </p>
          </div>

          {isLoading && trendingPosts.length === 0 ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Loading trending posts...</p>
            </div>
          ) : trendingPosts.length > 0 ? (
            <MasonryGrid columns={3} gap={16}>
              {trendingPosts.map((post) => (
                <PostCard key={post.post_id} post={post} />
              ))}
            </MasonryGrid>
          ) : (
            <div className="empty-state">
              <span className="empty-icon">🔍</span>
              <h3>No trending posts yet</h3>
              <p>Check back soon for viral content!</p>
            </div>
          )}
        </div>
      </main>

      <footer className="App-footer">
        <p>Google Cloud x Confluent Hackathon 2025 • YarimAI</p>
      </footer>
    </div>
  );
}

export default App;
