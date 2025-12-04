#!/bin/bash

# Test Data Generator for Viral Intelligence System
# This script generates sample events to test the system

API_URL="${1:-http://localhost:8080}"

echo "🎬 Generating test events for Viral Intelligence System"
echo "API URL: $API_URL"
echo ""

# Generate sample post IDs
POST_IDS=("post-001" "post-002" "post-003" "post-004" "post-005")
USER_IDS=("user-alice" "user-bob" "user-charlie" "user-diana" "user-eve")
CONTENT_TYPES=("image" "video" "music" "voice")
EVENT_TYPES=("view" "like" "comment" "share")

# Function to send content metadata
send_content() {
    local post_id=$1
    local user_id=$2
    local content_type=$3
    local prompt=$4

    echo "📝 Creating content: $post_id"
    curl -s -X POST "$API_URL/api/events/content" \
        -H "Content-Type: application/json" \
        -d "{
            \"post_id\": \"$post_id\",
            \"user_id\": \"$user_id\",
            \"content_type\": \"$content_type\",
            \"prompt\": \"$prompt\"
        }" | jq '.'
}

# Function to send interaction
send_interaction() {
    local post_id=$1
    local user_id=$2
    local event_type=$3

    curl -s -X POST "$API_URL/api/events/interaction" \
        -H "Content-Type: application/json" \
        -d "{
            \"post_id\": \"$post_id\",
            \"user_id\": \"$user_id\",
            \"event_type\": \"$event_type\"
        }" > /dev/null
}

# Function to send view
send_view() {
    local post_id=$1
    local user_id=$2
    local platform=$3

    curl -s -X POST "$API_URL/api/events/view" \
        -H "Content-Type: application/json" \
        -d "{
            \"post_id\": \"$post_id\",
            \"user_id\": \"$user_id\",
            \"platform\": \"$platform\",
            \"duration\": $((RANDOM % 60 + 10))
        }" > /dev/null
}

# Function to send remix
send_remix() {
    local original_id=$1
    local remix_id=$2
    local user_id=$3

    echo "🎵 Creating remix: $original_id -> $remix_id"
    curl -s -X POST "$API_URL/api/events/remix" \
        -H "Content-Type: application/json" \
        -d "{
            \"original_post_id\": \"$original_id\",
            \"remix_post_id\": \"$remix_id\",
            \"user_id\": \"$user_id\",
            \"remix_type\": \"style_transfer\"
        }" | jq '.'
}

# Create initial content
echo "📦 Creating initial content..."
send_content "post-001" "user-alice" "image" "A beautiful sunset over mountains with golden light"
sleep 1
send_content "post-002" "user-bob" "music" "Upbeat electronic dance music with heavy bass"
sleep 1
send_content "post-003" "user-charlie" "video" "Time-lapse of city lights at night"
sleep 1
send_content "post-004" "user-diana" "voice" "Dramatic narration of a fantasy story"
sleep 1
send_content "post-005" "user-eve" "image" "Abstract art with vibrant colors and geometric shapes"
sleep 2

echo ""
echo "🔥 Simulating viral content (post-001)..."
# Make post-001 go viral
for i in {1..50}; do
    user_idx=$((RANDOM % 5))
    event_idx=$((RANDOM % 4))
    platform=$( [ $((RANDOM % 2)) -eq 0 ] && echo "mobile" || echo "web" )
    
    send_view "post-001" "${USER_IDS[$user_idx]}" "$platform"
    send_interaction "post-001" "${USER_IDS[$user_idx]}" "${EVENT_TYPES[$event_idx]}"
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Generated $i interactions for post-001"
    fi
    
    sleep 0.1
done

echo ""
echo "📈 Simulating moderate engagement (post-002, post-003)..."
# Moderate engagement for other posts
for post in "post-002" "post-003"; do
    for i in {1..20}; do
        user_idx=$((RANDOM % 5))
        event_idx=$((RANDOM % 4))
        platform=$( [ $((RANDOM % 2)) -eq 0 ] && echo "mobile" || echo "web" )
        
        send_view "$post" "${USER_IDS[$user_idx]}" "$platform"
        send_interaction "$post" "${USER_IDS[$user_idx]}" "${EVENT_TYPES[$event_idx]}"
        
        sleep 0.1
    done
done

echo ""
echo "🎵 Creating remix chain..."
# Create remix chain
send_remix "post-001" "post-001-remix-1" "user-bob"
sleep 1
send_remix "post-001" "post-001-remix-2" "user-charlie"
sleep 1
send_remix "post-001-remix-1" "post-001-remix-3" "user-diana"

# Add engagement to remixes
for remix in "post-001-remix-1" "post-001-remix-2"; do
    for i in {1..10}; do
        user_idx=$((RANDOM % 5))
        send_view "$remix" "${USER_IDS[$user_idx]}" "mobile"
        send_interaction "$remix" "${USER_IDS[$user_idx]}" "like"
        sleep 0.1
    done
done

echo ""
echo "✅ Test data generation complete!"
echo ""
echo "📊 Check the dashboard to see:"
echo "  - post-001 should be trending (viral)"
echo "  - Remix chain for post-001"
echo "  - Real-time engagement metrics"
echo "  - Viral probability predictions"
echo ""
echo "🔍 Fetch trending posts:"
echo "curl $API_URL/api/analytics/trending?limit=10 | jq '.'"
