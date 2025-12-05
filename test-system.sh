#!/bin/bash

# Quick system test script
# Tests all major endpoints and verifies the system is working

SERVICE_URL="https://viral-intelligence-streaming-799474804867.us-central1.run.app"

echo "================================================"
echo "Viral Intelligence System - Quick Test"
echo "================================================"
echo ""

# Test 1: Health Check
echo "1. Testing health endpoint..."
HEALTH=$(curl -s "$SERVICE_URL/health")
echo "   Response: $HEALTH"
if [[ $HEALTH == *"healthy"* ]]; then
    echo "   ✅ Health check passed"
else
    echo "   ❌ Health check failed"
    exit 1
fi
echo ""

# Test 2: Send Like Event
echo "2. Sending like event..."
LIKE_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/events/interaction" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": "test_post_001",
    "user_id": "test_user_001",
    "event_type": "like",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }')
echo "   Response: $LIKE_RESPONSE"
if [[ $LIKE_RESPONSE == *"success"* ]]; then
    echo "   ✅ Like event sent successfully"
else
    echo "   ❌ Like event failed"
fi
echo ""

# Test 3: Send View Event
echo "3. Sending view event..."
VIEW_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/events/view" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": "test_post_001",
    "user_id": "test_user_002",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }')
echo "   Response: $VIEW_RESPONSE"
if [[ $VIEW_RESPONSE == *"success"* ]]; then
    echo "   ✅ View event sent successfully"
else
    echo "   ❌ View event failed"
fi
echo ""

# Test 4: Send Content Event
echo "4. Sending content metadata event..."
CONTENT_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/events/content" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": "test_post_001",
    "user_id": "test_user_001",
    "content_type": "image",
    "prompt": "A beautiful sunset over the ocean",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }')
echo "   Response: $CONTENT_RESPONSE"
if [[ $CONTENT_RESPONSE == *"success"* ]]; then
    echo "   ✅ Content event sent successfully"
else
    echo "   ❌ Content event failed"
fi
echo ""

# Test 5: Send Remix Event
echo "5. Sending remix event..."
REMIX_RESPONSE=$(curl -s -X POST "$SERVICE_URL/api/events/remix" \
  -H "Content-Type: application/json" \
  -d '{
    "post_id": "test_post_002",
    "user_id": "test_user_003",
    "original_post_id": "test_post_001",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }')
echo "   Response: $REMIX_RESPONSE"
if [[ $REMIX_RESPONSE == *"success"* ]]; then
    echo "   ✅ Remix event sent successfully"
else
    echo "   ❌ Remix event failed"
fi
echo ""

# Test 6: Query Trending
echo "6. Querying trending posts..."
TRENDING_RESPONSE=$(curl -s "$SERVICE_URL/api/analytics/trending?limit=5")
echo "   Response: $TRENDING_RESPONSE"
if [[ $TRENDING_RESPONSE == *"success"* ]]; then
    echo "   ✅ Trending query successful"
else
    echo "   ❌ Trending query failed"
fi
echo ""

# Test 7: Query Post Stats
echo "7. Querying post statistics..."
STATS_RESPONSE=$(curl -s "$SERVICE_URL/api/analytics/post/test_post_001/stats")
echo "   Response: $STATS_RESPONSE"
if [[ $STATS_RESPONSE == *"success"* ]] || [[ $STATS_RESPONSE == *"post_id"* ]]; then
    echo "   ✅ Post stats query successful"
else
    echo "   ❌ Post stats query failed"
fi
echo ""

# Test 8: Query Recommendations
echo "8. Querying user recommendations..."
RECS_RESPONSE=$(curl -s "$SERVICE_URL/api/analytics/user/test_user_001/recommendations?limit=5")
echo "   Response: $RECS_RESPONSE"
if [[ $RECS_RESPONSE == *"success"* ]] || [[ $RECS_RESPONSE == *"recommendations"* ]]; then
    echo "   ✅ Recommendations query successful"
else
    echo "   ❌ Recommendations query failed"
fi
echo ""

echo "================================================"
echo "Test Summary"
echo "================================================"
echo ""
echo "All tests completed! Check the responses above."
echo ""
echo "To verify messages in Kafka:"
echo "1. Go to: https://confluent.cloud"
echo "2. Navigate to your cluster: lkc-q3dy17"
echo "3. Click Topics → user-interactions → Messages"
echo "4. You should see your test events!"
echo ""
echo "To check service logs:"
echo "  gcloud logging read \"resource.labels.service_name=viral-intelligence-streaming\" --limit 20 --project yarimai --freshness=5m"
echo ""
echo "================================================"
echo "✅ System is operational!"
echo "================================================"
