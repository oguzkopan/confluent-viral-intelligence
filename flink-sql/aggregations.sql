-- Flink SQL Statements for Real-Time Viral Content Intelligence
-- Execute these in Confluent Cloud Flink SQL workspace

-- ============================================
-- 1. Create Tables from Kafka Topics
-- ============================================

-- User Interactions Table
CREATE TABLE user_interactions (
    post_id STRING,
    user_id STRING,
    event_type STRING,
    event_timestamp TIMESTAMP(3),
    WATERMARK FOR event_timestamp AS event_timestamp - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-interactions',
    'properties.bootstrap.servers' = 'YOUR_BOOTSTRAP_SERVER',
    'properties.group.id' = 'flink-aggregations',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- View Events Table
CREATE TABLE view_events (
    post_id STRING,
    user_id STRING,
    viewed_at TIMESTAMP(3),
    duration INT,
    platform STRING,
    WATERMARK FOR viewed_at AS viewed_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'view-events',
    'properties.bootstrap.servers' = 'YOUR_BOOTSTRAP_SERVER',
    'properties.group.id' = 'flink-aggregations',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- Remix Events Table
CREATE TABLE remix_events (
    original_post_id STRING,
    remix_post_id STRING,
    user_id STRING,
    remixed_at TIMESTAMP(3),
    WATERMARK FOR remixed_at AS remixed_at - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'remix-events',
    'properties.bootstrap.servers' = 'YOUR_BOOTSTRAP_SERVER',
    'properties.group.id' = 'flink-aggregations',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json'
);

-- Trending Scores Output Table
CREATE TABLE trending_scores (
    post_id STRING,
    score DOUBLE,
    engagement_rate DOUBLE,
    view_count BIGINT,
    like_count BIGINT,
    comment_count BIGINT,
    share_count BIGINT,
    remix_count BIGINT,
    engagement_velocity DOUBLE,
    calculated_at TIMESTAMP(3),
    time_window STRING,
    PRIMARY KEY (post_id) NOT ENFORCED
) WITH (
    'connector' = 'upsert-kafka',
    'topic' = 'trending-scores',
    'properties.bootstrap.servers' = 'YOUR_BOOTSTRAP_SERVER',
    'key.format' = 'raw',
    'value.format' = 'json'
);

-- ============================================
-- 2. Real-Time Aggregations (1-minute window)
-- ============================================

-- Calculate engagement metrics per post in 1-minute tumbling windows
INSERT INTO trending_scores
SELECT 
    post_id,
    -- Calculate trending score (weighted sum of interactions)
    CAST(
        (COUNT(CASE WHEN event_type = 'view' THEN 1 END) * 1.0) +
        (COUNT(CASE WHEN event_type = 'like' THEN 1 END) * 2.0) +
        (COUNT(CASE WHEN event_type = 'comment' THEN 1 END) * 3.0) +
        (COUNT(CASE WHEN event_type = 'share' THEN 1 END) * 5.0)
    AS DOUBLE) as score,
    
    -- Engagement rate (interactions per view)
    CAST(
        CASE 
            WHEN COUNT(CASE WHEN event_type = 'view' THEN 1 END) > 0 
            THEN (COUNT(*) - COUNT(CASE WHEN event_type = 'view' THEN 1 END)) * 1.0 / 
                 COUNT(CASE WHEN event_type = 'view' THEN 1 END)
            ELSE 0.0
        END
    AS DOUBLE) as engagement_rate,
    
    -- Individual counts
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) as view_count,
    COUNT(CASE WHEN event_type = 'like' THEN 1 END) as like_count,
    COUNT(CASE WHEN event_type = 'comment' THEN 1 END) as comment_count,
    COUNT(CASE WHEN event_type = 'share' THEN 1 END) as share_count,
    0 as remix_count, -- Will be updated by remix aggregation
    
    -- Engagement velocity (interactions per minute)
    CAST(COUNT(*) AS DOUBLE) as engagement_velocity,
    
    CURRENT_TIMESTAMP as calculated_at,
    '1min' as time_window
FROM user_interactions
GROUP BY 
    post_id,
    TUMBLE(event_timestamp, INTERVAL '1' MINUTE);

-- ============================================
-- 3. View Count Aggregation
-- ============================================

-- Aggregate view counts separately for more accurate tracking
CREATE VIEW view_aggregations AS
SELECT 
    post_id,
    COUNT(*) as total_views,
    COUNT(DISTINCT user_id) as unique_viewers,
    AVG(duration) as avg_view_duration,
    TUMBLE_END(viewed_at, INTERVAL '1' MINUTE) as window_end
FROM view_events
GROUP BY 
    post_id,
    TUMBLE(viewed_at, INTERVAL '1' MINUTE);

-- ============================================
-- 4. Remix Chain Tracking
-- ============================================

-- Track remix counts and boost original post scores
CREATE VIEW remix_aggregations AS
SELECT 
    original_post_id as post_id,
    COUNT(*) as remix_count,
    COUNT(DISTINCT user_id) as unique_remixers,
    TUMBLE_END(remixed_at, INTERVAL '5' MINUTE) as window_end
FROM remix_events
GROUP BY 
    original_post_id,
    TUMBLE(remixed_at, INTERVAL '5' MINUTE);

-- Update trending scores with remix boost
INSERT INTO trending_scores
SELECT 
    post_id,
    CAST(remix_count * 4.0 AS DOUBLE) as score, -- Remixes are highly valuable
    0.0 as engagement_rate,
    0 as view_count,
    0 as like_count,
    0 as comment_count,
    0 as share_count,
    remix_count,
    CAST(remix_count AS DOUBLE) as engagement_velocity,
    CURRENT_TIMESTAMP as calculated_at,
    '5min' as time_window
FROM remix_aggregations;

-- ============================================
-- 5. Hourly Trending Aggregation
-- ============================================

-- Calculate hourly trending scores for longer-term trends
CREATE VIEW hourly_trending AS
SELECT 
    post_id,
    CAST(
        (COUNT(CASE WHEN event_type = 'view' THEN 1 END) * 1.0) +
        (COUNT(CASE WHEN event_type = 'like' THEN 1 END) * 2.0) +
        (COUNT(CASE WHEN event_type = 'comment' THEN 1 END) * 3.0) +
        (COUNT(CASE WHEN event_type = 'share' THEN 1 END) * 5.0)
    AS DOUBLE) as hourly_score,
    COUNT(*) as total_interactions,
    TUMBLE_END(event_timestamp, INTERVAL '1' HOUR) as window_end
FROM user_interactions
GROUP BY 
    post_id,
    TUMBLE(event_timestamp, INTERVAL '1' HOUR);

-- ============================================
-- 6. Real-Time Top Trending (Continuous Query)
-- ============================================

-- Get top 20 trending posts in real-time
CREATE VIEW top_trending AS
SELECT 
    post_id,
    score,
    engagement_velocity,
    view_count,
    like_count,
    share_count,
    remix_count,
    calculated_at
FROM trending_scores
WHERE time_window = '1min'
ORDER BY score DESC
LIMIT 20;

-- ============================================
-- 7. User Engagement Patterns (for Recommendations)
-- ============================================

-- Track user interaction patterns for personalized recommendations
CREATE VIEW user_engagement_patterns AS
SELECT 
    user_id,
    COUNT(DISTINCT post_id) as posts_interacted,
    COUNT(CASE WHEN event_type = 'like' THEN 1 END) as likes_given,
    COUNT(CASE WHEN event_type = 'share' THEN 1 END) as shares_made,
    TUMBLE_END(event_timestamp, INTERVAL '5' MINUTE) as window_end
FROM user_interactions
GROUP BY 
    user_id,
    TUMBLE(event_timestamp, INTERVAL '5' MINUTE);

-- ============================================
-- NOTES:
-- ============================================
-- 1. Replace 'YOUR_BOOTSTRAP_SERVER' with your actual Confluent Cloud bootstrap server
-- 2. Execute these statements in order in the Flink SQL workspace
-- 3. Monitor the Flink jobs in the Confluent Cloud console
-- 4. Adjust window sizes based on your traffic patterns
-- 5. The trending_scores topic will receive real-time updates every minute
