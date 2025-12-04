import React, { useState, useEffect } from 'react';
import './App.css';
import TrendingFeed from './components/TrendingFeed';
import ViralPredictions from './components/ViralPredictions';
import RealTimeMetrics from './components/RealTimeMetrics';
import WebSocketStatus from './components/WebSocketStatus';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';
const WS_URL = process.env.REACT_APP_WS_URL || 'ws://localhost:8080/ws';

function App() {
  const [trendingPosts, setTrendingPosts] = useState([]);
  const [viralAlerts, setViralAlerts] = useState([]);
  const [wsConnected, setWsConnected] = useState(false);
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
        // Play notification sound or show toast
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
      const response = await fetch(`${API_URL}/api/analytics/trending?limit=20`);
      const data = await response.json();
      setTrendingPosts(data.trending || []);
      
      // Update metrics
      const viralCount = data.trending.filter(p => p.viral_probability > 0.7).length;
      setMetrics({
        totalViews: data.trending.reduce((sum, p) => sum + p.view_count, 0),
        totalInteractions: data.trending.reduce((sum, p) => 
          sum + p.like_count + p.comment_count + p.share_count, 0),
        viralPosts: viralCount
      });
    } catch (error) {
      console.error('Failed to fetch trending:', error);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🔥 Real-Time Viral Content Intelligence</h1>
        <p>Powered by Confluent Cloud + Google Cloud Vertex AI</p>
        <WebSocketStatus connected={wsConnected} />
      </header>

      <main className="App-main">
        <RealTimeMetrics metrics={metrics} />
        
        <div className="dashboard-grid">
          <div className="dashboard-section">
            <h2>📈 Trending Now</h2>
            <TrendingFeed posts={trendingPosts} />
          </div>

          <div className="dashboard-section">
            <h2>🚀 Viral Predictions</h2>
            <ViralPredictions posts={trendingPosts.filter(p => p.viral_probability > 0.5)} />
          </div>
        </div>

        {viralAlerts.length > 0 && (
          <div className="viral-alerts">
            <h2>🔔 Recent Viral Alerts</h2>
            {viralAlerts.map((alert, index) => (
              <div key={index} className="viral-alert">
                Post {alert.post_id} is going viral! ({(alert.probability * 100).toFixed(0)}% probability)
              </div>
            ))}
          </div>
        )}
      </main>

      <footer className="App-footer">
        <p>Google Cloud x Confluent Hackathon 2025</p>
      </footer>
    </div>
  );
}

export default App;
