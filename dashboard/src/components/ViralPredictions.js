import React from 'react';
import './ViralPredictions.css';

function ViralPredictions({ posts }) {
  if (!posts || posts.length === 0) {
    return <div className="empty-state">No viral predictions yet...</div>;
  }

  const sortedPosts = [...posts].sort((a, b) => b.viral_probability - a.viral_probability);

  return (
    <div className="viral-predictions">
      {sortedPosts.map((post) => (
        <div key={post.post_id} className="prediction-item">
          <div className="prediction-header">
            <span className="post-id">Post: {post.post_id.substring(0, 8)}...</span>
            <span className={`probability ${getProbabilityClass(post.viral_probability)}`}>
              {(post.viral_probability * 100).toFixed(0)}%
            </span>
          </div>
          
          <div className="probability-bar">
            <div 
              className="probability-fill"
              style={{ width: `${post.viral_probability * 100}%` }}
            />
          </div>

          <div className="prediction-details">
            <div className="detail-item">
              <span className="detail-label">Engagement Velocity:</span>
              <span className="detail-value">{post.engagement_velocity.toFixed(1)}/min</span>
            </div>
            <div className="detail-item">
              <span className="detail-label">Total Engagement:</span>
              <span className="detail-value">
                {post.like_count + post.comment_count + post.share_count + post.remix_count}
              </span>
            </div>
          </div>

          {post.viral_probability > 0.7 && (
            <div className="viral-badge">🔥 GOING VIRAL!</div>
          )}
        </div>
      ))}
    </div>
  );
}

function getProbabilityClass(probability) {
  if (probability > 0.7) return 'high';
  if (probability > 0.5) return 'medium';
  return 'low';
}

export default ViralPredictions;
