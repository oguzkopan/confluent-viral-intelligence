import React from 'react';
import './PostCard.css';

const PostCard = ({ post }) => {
  const handleCardClick = () => {
    // Navigate to main app's post detail view
    window.open(`https://yarimai.com/post/${post.post_id}`, '_blank');
  };

  const formatCount = (count) => {
    if (count >= 1000000) {
      return `${(count / 1000000).toFixed(1)}M`;
    }
    if (count >= 1000) {
      return `${(count / 1000).toFixed(1)}K`;
    }
    return count.toString();
  };

  const getMediaContent = () => {
    const contentType = post.contentType || post.content_type || 'image';
    const outputUrls = post.outputUrls || post.output_urls || [];

    switch (contentType) {
      case 'image':
        return outputUrls.length > 0 ? (
          <img
            src={outputUrls[0]}
            alt={post.title || 'Generated image'}
            className="post-media"
            loading="lazy"
          />
        ) : (
          <div className="placeholder-card">
            <span className="placeholder-icon">🖼️</span>
            <span className="placeholder-text">Image</span>
          </div>
        );
      case 'video':
        return outputUrls.length > 0 ? (
          <video
            src={outputUrls[0]}
            className="post-media"
            preload="metadata"
            playsInline
            muted
          />
        ) : (
          <div className="placeholder-card">
            <span className="placeholder-icon">🎬</span>
            <span className="placeholder-text">Video</span>
          </div>
        );
      case 'music':
        return (
          <div className="audio-card">
            <div className="audio-visual">
              <div className="audio-icon">🎵</div>
              <div className="audio-title">{post.title || 'Audio Track'}</div>
            </div>
          </div>
        );
      case 'voice':
        return (
          <div className="voice-card">
            <div className="voice-visual">
              <div className="voice-icon">🎙️</div>
              <div className="voice-info">
                <div className="voice-name">{post.title || 'Voice Generation'}</div>
              </div>
            </div>
          </div>
        );
      case 'text':
        return (
          <div className="text-card">
            <div className="text-content">
              {(post.outputText || post.output_text) && (post.outputText || post.output_text).length > 300
                ? (post.outputText || post.output_text).slice(0, 300) + '...'
                : (post.outputText || post.output_text) || ''}
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  const getViralBadge = () => {
    if (post.viral_probability && post.viral_probability > 0.7) {
      return (
        <div className="viral-badge">
          🔥 {(post.viral_probability * 100).toFixed(0)}% Viral
        </div>
      );
    }
    return null;
  };

  return (
    <article className="post-card" onClick={handleCardClick}>
      {/* Viral Badge */}
      {getViralBadge()}

      {/* Media Content */}
      <div className="media-container">{getMediaContent()}</div>

      {/* Post Info */}
      <div className="post-info">
        {/* Creator Info */}
        {post.user && (
          <div className="creator">
            {post.user.photoURL || post.user.photo_url ? (
              <img
                src={post.user.photoURL || post.user.photo_url}
                alt={post.user.displayName || post.user.display_name}
                className="avatar"
              />
            ) : (
              <div className="avatar-placeholder">
                {(post.user.displayName || post.user.display_name)?.[0]?.toUpperCase() || '?'}
              </div>
            )}
            <div className="creator-info">
              <span className="display-name">{post.user.displayName || post.user.display_name}</span>
              {(post.user.username) && (
                <span className="username">@{post.user.username}</span>
              )}
            </div>
          </div>
        )}

        {/* Title */}
        {post.title && <h3 className="post-title">{post.title}</h3>}

        {/* Description */}
        {post.description && (
          <div className="post-description">
            {post.description.length > 150
              ? post.description.slice(0, 150) + '...'
              : post.description}
          </div>
        )}

        {/* Engagement Metrics */}
        <div className="metrics">
          <div className="metric-item">
            <span className="metric-icon">❤️</span>
            <span className="metric-count">{formatCount(post.likeCount || post.like_count || 0)}</span>
          </div>
          <div className="metric-item">
            <span className="metric-icon">💬</span>
            <span className="metric-count">{formatCount(post.commentCount || post.comment_count || 0)}</span>
          </div>
          <div className="metric-item">
            <span className="metric-icon">👁️</span>
            <span className="metric-count">{formatCount(post.viewCount || post.view_count || 0)}</span>
          </div>
        </div>

        {/* Viral Intelligence Metrics */}
        <div className="viral-metrics">
          <div className="viral-metric">
            <span className="viral-label">Score:</span>
            <span className="viral-value">{post.score?.toFixed(1) || '0.0'}</span>
          </div>
          <div className="viral-metric">
            <span className="viral-label">Velocity:</span>
            <span className="viral-value">
              {post.engagement_velocity?.toFixed(1) || '0.0'}/h
            </span>
          </div>
        </div>
      </div>
    </article>
  );
};

export default PostCard;
