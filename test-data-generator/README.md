# Test Data Generator

This directory contains a test data generator script for the Confluent Viral Intelligence System. The script simulates realistic user interactions and content creation events to test the streaming pipeline.

## Overview

The `generate_events.sh` script creates various test scenarios including:

1. **Viral Content** - High engagement content with 50+ views, 30 likes, 15 comments, 10 shares
2. **Moderate Engagement** - 5 posts with 10-20 views and moderate interactions
3. **Remix Chain** - A 3-level deep remix chain showing content attribution
4. **Low Engagement** - 3 posts with minimal interaction
5. **Activity Burst** - 30 seconds of rapid real-time events

## Prerequisites

- `curl` - For making HTTP requests
- `jq` - For JSON formatting (optional, for verbose mode)
- Streaming service running (locally or on Cloud Run)

## Usage

### Basic Usage

Run with default settings (localhost:8080):

```bash
./generate_events.sh
```

### Custom API URL

Point to a deployed Cloud Run service:

```bash
./generate_events.sh --api-url https://viral-intelligence-streaming-xxxxx.run.app
```

### Verbose Mode

See detailed request/response information:

```bash
./generate_events.sh --verbose
```

### Using Environment Variables

```bash
API_URL=http://localhost:8080 VERBOSE=true ./generate_events.sh
```

## Test Scenarios

### Scenario 1: Viral Content
- Creates 1 video post with high engagement
- Generates 50 views from random users
- Adds 30 likes, 15 comments, 10 shares
- Tests viral prediction algorithms

### Scenario 2: Moderate Engagement
- Creates 5 posts with different content types (image, video, music, voice)
- Each post gets 10-20 views, 5-10 likes, 2-5 comments, 1-3 shares
- Tests normal content performance

### Scenario 3: Remix Chain
- Creates original content
- Generates 2 first-level remixes
- Creates 1 second-level remix (remix of remix)
- Creates 1 third-level remix
- Tests remix attribution and chain tracking

### Scenario 4: Low Engagement
- Creates 3 posts with minimal interaction
- 1-3 views, 0-1 likes per post
- Tests handling of low-performing content

### Scenario 5: Activity Burst
- Creates 1 post
- Generates rapid events over 30 seconds
- Tests real-time processing and WebSocket updates

## Generated Events

The script generates the following event types:

### Content Creation Events
```json
{
  "post_id": "post_001",
  "user_id": "user_001",
  "content_type": "video",
  "prompt": "Epic sunset timelapse...",
  "created_at": "2024-12-05T00:00:00Z"
}
```

### Interaction Events
```json
{
  "post_id": "post_001",
  "user_id": "user_002",
  "event_type": "like",
  "timestamp": "2024-12-05T00:00:00Z"
}
```

### View Events
```json
{
  "post_id": "post_001",
  "user_id": "user_003",
  "viewed_at": "2024-12-05T00:00:00Z",
  "duration": 45,
  "platform": "mobile"
}
```

### Remix Events
```json
{
  "original_post_id": "post_001",
  "remix_post_id": "post_002",
  "user_id": "user_004",
  "remixed_at": "2024-12-05T00:00:00Z"
}
```

## Monitoring Results

### Check Trending Content

```bash
curl -s http://localhost:8080/api/analytics/trending?limit=10 | jq
```

### Watch Real-time Updates

```bash
watch -n 2 'curl -s http://localhost:8080/api/analytics/trending?limit=10 | jq'
```

### Check Specific Post Stats

```bash
curl -s http://localhost:8080/api/analytics/post/post_viral_001/stats | jq
```

## Verification Steps

After running the script:

1. **Check Confluent Cloud**
   - Open Confluent Cloud console
   - Navigate to Topics
   - Verify events in: `user-interactions`, `content-metadata`, `view-events`, `remix-events`

2. **Check Flink Jobs**
   - Open Flink SQL workspace
   - Verify jobs are running
   - Check `trending-scores` topic for aggregated results

3. **Check Firestore**
   - Open Firebase console
   - Navigate to Firestore
   - Check `trending_scores` collection
   - Verify `posts` collection has updated metadata

4. **Check Dashboard**
   - Open the React dashboard
   - Verify WebSocket connection is active
   - See real-time trending updates
   - Check viral predictions

## Troubleshooting

### API Not Reachable

If you see "API health check failed":
- Verify the streaming service is running
- Check the API URL is correct
- Ensure firewall/network allows connections

### Events Not Appearing

If events don't show up in Confluent Cloud:
- Check streaming service logs
- Verify Kafka credentials are correct
- Ensure topics exist in Confluent Cloud

### No Trending Scores

If trending scores aren't calculated:
- Verify Flink jobs are running
- Check Flink job logs for errors
- Ensure window period has elapsed (1 minute)

## Performance Notes

- The script generates ~200+ events total
- Execution time: ~2-3 minutes
- Network latency affects timing
- Use `--verbose` to debug issues

## Integration Testing

Use this script for:
- End-to-end pipeline testing
- Load testing (run multiple instances)
- Demo preparation
- Development validation

## Example Output

```
[INFO] Starting Test Data Generator for Confluent Viral Intelligence System
[INFO] API URL: http://localhost:8080

[SUCCESS] API is reachable

[INFO] === Scenario 1: Viral Content ===
[INFO] Creating viral video content...
[INFO] Generating high engagement for viral content...
[INFO]   Generated 10 views...
[INFO]   Generated 20 views...
[INFO]   Generated 30 views...
[INFO]   Generated 40 views...
[INFO]   Generated 50 views...
[INFO]   Generated 30 likes
[INFO]   Generated 15 comments
[INFO]   Generated 10 shares
[SUCCESS] Viral content scenario complete

...

[INFO] === Test Data Generation Complete ===
[SUCCESS] Generated test data for:
  ✓ 1 viral content with high engagement
  ✓ 5 moderate engagement posts
  ✓ 1 remix chain (3 levels deep)
  ✓ 3 low engagement posts
  ✓ 1 real-time activity burst
```

## Notes

- User IDs are randomly selected from a pool of 13 test users
- Post IDs follow naming conventions for easy identification
- Timestamps are generated in real-time (ISO 8601 format)
- Platform is randomly selected (mobile/web) for view events
- Duration is randomized within realistic ranges

## Future Enhancements

- Add command-line options for custom scenarios
- Support for batch event generation
- CSV/JSON input file support
- Performance metrics collection
- Concurrent event generation
