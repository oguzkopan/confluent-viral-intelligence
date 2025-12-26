import React from 'react';
import './EnhancedMetrics.css';

const EnhancedMetrics = ({ metrics, topPosts, topCreators }) => {
  const formatNumber = (num) => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`;
    }
    if (num >= 1000) {
      return `${(num / 1000).toFixed(1)}K`;
    }
    return num.toString();
  };

  return (
    <div className="enhanced-metrics">
      {/* Main Metrics Cards */}
      <div className="metrics-grid">
        <div className="metric-card">
          <div className="metric-icon">👁️</div>
          <div className="metric-content">
            <div className="metric-value">{formatNumber(metrics.totalViews || 0)}</div>
            <div className="metric-label">Total Views</div>
          </div>
        </div>

        <div className="metric-card">
          <div className="metric-icon">⚡</div>
          <div className="metric-content">
            <div className="metric-value">{formatNumber(metrics.totalInteractions || 0)}</div>
            <div className="metric-label">Total Interactions</div>
          </div>
        </div>

        <div className="metric-card highlight">
          <div className="metric-icon">🔥</div>
          <div className="metric-content">
            <div className="metric-value">{metrics.viralPosts || 0}</div>
            <div className="metric-label">Viral Posts</div>
          </div>
        </div>

        <div className="metric-card">
          <div className="metric-icon">📊</div>
          <div className="metric-content">
            <div className="metric-value">{metrics.totalPosts || 0}</div>
            <div className="metric-label">Total Posts</div>
          </div>
        </div>

        <div className="metric-card">
          <div className="metric-icon">👥</div>
          <div className="metric-content">
            <div className="metric-value">{metrics.activeUsers || 0}</div>
            <div className="metric-label">Active Creators</div>
          </div>
        </div>

        <div className="metric-card">
          <div className="metric-icon">💯</div>
          <div className="metric-content">
            <div className="metric-value">{metrics.engagementRate?.toFixed(1) || 0}%</div>
            <div className="metric-label">Engagement Rate</div>
          </div>
        </div>
      </div>

      {/* Top 3 Content Section */}
      {topPosts && topPosts.length > 0 && (
        <div className="top-content-section">
          <h3 className="section-title">🏆 Top 3 Trending Content</h3>
          <div className="top-content-grid">
            {topPosts.map((post, index) => (
              <div key={post.post_id} className={`top-content-card rank-${index + 1}`}>
                <div className="rank-badge">#{index + 1}</div>
                
                {/* Content Preview */}
                {post.output_urls && post.output_urls.length > 0 && (
                  <div className="content-preview">
                    {post.content_type === 'video' ? (
                      <video 
                        src={post.output_urls[0]} 
                        controls 
                        className="content-media"
                        poster={post.output_urls[0]}
                      />
                    ) : post.content_type === 'music' || post.content_type === 'voice' ? (
                      <div className="audio-preview">
                        <div className="audio-icon">
                          {post.content_type === 'music' ? '🎵' : '🎙️'}
                        </div>
                        <audio 
                          src={post.output_urls[0]} 
                          controls 
                          className="content-audio"
                        />
                      </div>
                    ) : (
                      <img 
                        src={post.output_urls[0]} 
                        alt={post.title || 'Trending content'} 
                        className="content-media"
                      />
                    )}
                  </div>
                )}
                
                {/* Content Info */}
                {(post.title || post.instructions) && (
                  <div className="content-info">
                    {post.title && (
                      <div className="content-title">{post.title}</div>
                    )}
                    {post.instructions && (
                      <div className="content-prompt">{post.instructions}</div>
                    )}
                  </div>
                )}
                
                {/* Stats */}
                <div className="content-stats">
                  <div className="stat-row">
                    <span className="stat-label">Score:</span>
                    <span className="stat-value">{post.score?.toFixed(1) || 0}</span>
                  </div>
                  <div className="stat-row">
                    <span className="stat-label">Views:</span>
                    <span className="stat-value">{formatNumber(post.view_count || 0)}</span>
                  </div>
                  <div className="stat-row">
                    <span className="stat-label">Likes:</span>
                    <span className="stat-value">{formatNumber(post.like_count || 0)}</span>
                  </div>
                  <div className="stat-row">
                    <span className="stat-label">Comments:</span>
                    <span className="stat-value">{formatNumber(post.comment_count || 0)}</span>
                  </div>
                  {post.viral_probability > 0.7 && (
                    <div className="viral-indicator">
                      🔥 {(post.viral_probability * 100).toFixed(0)}% Viral
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Top Creators Section */}
      {topCreators && topCreators.length > 0 && (
        <div className="top-creators-section">
          <h3 className="section-title">⭐ Popular Creators</h3>
          <div className="creators-list">
            {topCreators.map((creator, index) => (
              <div key={creator.userId} className="creator-card">
                <div className="creator-rank">#{index + 1}</div>
                <div className="creator-avatar">
                  {creator.photoUrl ? (
                    <img src={creator.photoUrl} alt={creator.displayName} />
                  ) : (
                    <div className="avatar-placeholder">
                      {creator.displayName?.[0]?.toUpperCase() || '?'}
                    </div>
                  )}
                </div>
                <div className="creator-info">
                  <div className="creator-name">{creator.displayName || 'Unknown'}</div>
                  {creator.username && (
                    <div className="creator-username">@{creator.username}</div>
                  )}
                  <div className="creator-stats">
                    <span className="creator-stat">
                      <span className="stat-icon">📊</span>
                      {creator.postCount} posts
                    </span>
                    <span className="creator-stat">
                      <span className="stat-icon">👁️</span>
                      {formatNumber(creator.totalViews)}
                    </span>
                    <span className="creator-stat">
                      <span className="stat-icon">❤️</span>
                      {formatNumber(creator.totalLikes)}
                    </span>
                    {creator.viralPostCount > 0 && (
                      <span className="creator-stat viral">
                        <span className="stat-icon">🔥</span>
                        {creator.viralPostCount} viral
                      </span>
                    )}
                  </div>
                  <div className="creator-metrics">
                    <div className="metric-item">
                      <span className="metric-label">Avg Score:</span>
                      <span className="metric-value">{creator.averageScore?.toFixed(1) || 0}</span>
                    </div>
                    <div className="metric-item">
                      <span className="metric-label">Engagement:</span>
                      <span className="metric-value">{creator.engagementRate?.toFixed(1) || 0}%</span>
                    </div>
                    {creator.followerCount > 0 && (
                      <div className="metric-item">
                        <span className="metric-label">Followers:</span>
                        <span className="metric-value">{formatNumber(creator.followerCount)}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Content Type Distribution */}
      {metrics.topContentTypes && Object.keys(metrics.topContentTypes).length > 0 && (
        <div className="content-types-section">
          <h3 className="section-title">📈 Content Type Distribution</h3>
          <div className="content-types-grid">
            {Object.entries(metrics.topContentTypes).map(([type, count]) => {
              const percentage = ((count / metrics.totalPosts) * 100).toFixed(1);
              const icon = {
                image: '🖼️',
                video: '🎬',
                music: '🎵',
                voice: '🎙️',
                text: '📝'
              }[type] || '📄';
              
              return (
                <div key={type} className="content-type-card">
                  <div className="content-type-icon">{icon}</div>
                  <div className="content-type-info">
                    <div className="content-type-name">{type}</div>
                    <div className="content-type-count">{count} posts</div>
                    <div className="content-type-percentage">{percentage}%</div>
                  </div>
                  <div className="content-type-bar">
                    <div 
                      className="content-type-fill" 
                      style={{ width: `${percentage}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default EnhancedMetrics;
