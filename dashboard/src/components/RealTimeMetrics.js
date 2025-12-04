import React from 'react';
import './RealTimeMetrics.css';

function RealTimeMetrics({ metrics }) {
  return (
    <div className="metrics-container">
      <div className="metric-card">
        <div className="metric-icon">👁️</div>
        <div className="metric-info">
          <div className="metric-value">{metrics.totalViews.toLocaleString()}</div>
          <div className="metric-label">Total Views</div>
        </div>
      </div>

      <div className="metric-card">
        <div className="metric-icon">⚡</div>
        <div className="metric-info">
          <div className="metric-value">{metrics.totalInteractions.toLocaleString()}</div>
          <div className="metric-label">Total Interactions</div>
        </div>
      </div>

      <div className="metric-card viral">
        <div className="metric-icon">🔥</div>
        <div className="metric-info">
          <div className="metric-value">{metrics.viralPosts}</div>
          <div className="metric-label">Viral Posts</div>
        </div>
      </div>
    </div>
  );
}

export default RealTimeMetrics;
