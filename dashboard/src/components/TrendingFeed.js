import React from 'react';
import './TrendingFeed.css';

function TrendingFeed({ posts }) {
  if (!posts || posts.length === 0) {
    return <div className="empty-state">No trending posts yet...</div>;
  }

  return (
    <div className="trending-feed">
      {posts.map((post, index) => (
        <div key={post.post_id} className="trending-item">
          <div className="trending-rank">#{index + 1}</div>
          <div className="trending-content">
            <div className="trending-id">Post: {post.post_id.substring(0, 8)}...</div>
            <div className="trending-stats">
              <span>👁️ {post.view_count}</span>
              <span>❤️ {post.like_count}</span>
              <span>💬 {post.comment_count}</span>
              <span>🔄 {post.share_count}</span>
              {post.remix_count > 0 && <span>🎵 {post.remix_count}</span>}
            </div>
            <div className="trending-metrics">
              <div className="metric">
                <span className="metric-label">Score:</span>
                <span className="metric-value">{post.score.toFixed(1)}</span>
              </div>
              <div className="metric">
                <span className="metric-label">Velocity:</span>
                <span className="metric-value">{post.engagement_velocity.toFixed(1)}/min</span>
              </div>
              {post.viral_probability && (
                <div className="metric viral-prob">
                  <span className="metric-label">Viral:</span>
                  <span className="metric-value">
                    {(post.viral_probability * 100).toFixed(0)}%
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default TrendingFeed;
