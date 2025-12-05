#!/bin/bash

# Test Data Generator for Confluent Viral Intelligence System
# This script generates sample events to test the streaming pipeline

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8080}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper function to make API calls
make_request() {
    local endpoint=$1
    local data=$2
    
    if [ "$VERBOSE" = "true" ]; then
        log_info "POST ${API_URL}${endpoint}"
        echo "$data" | jq '.' 2>/dev/null || echo "$data"
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "${API_URL}${endpoint}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        return 0
    else
        log_error "Request failed with status $http_code: $body"
        return 1
    fi
}

# Generate timestamp in ISO 8601 format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Generate random user ID
get_random_user() {
    local users=("user_001" "user_002" "user_003" "user_004" "user_005" 
                 "user_006" "user_007" "user_008" "user_009" "user_010"
                 "creator_alpha" "creator_beta" "creator_gamma")
    echo "${users[$RANDOM % ${#users[@]}]}"
}

# Generate random post ID
get_random_post() {
    echo "post_$(printf '%04d' $((RANDOM % 100 + 1)))"
}

# Generate content creation event
create_content() {
    local post_id=$1
    local user_id=$2
    local content_type=$3
    local prompt=$4
    local timestamp=$(get_timestamp)
    
    local data=$(cat <<EOF
{
    "post_id": "$post_id",
    "user_id": "$user_id",
    "content_type": "$content_type",
    "prompt": "$prompt",
    "created_at": "$timestamp"
}
EOF
)
    
    make_request "/api/events/content" "$data"
}

# Generate interaction event
create_interaction() {
    local post_id=$1
    local user_id=$2
    local event_type=$3
    local timestamp=$(get_timestamp)
    
    local data=$(cat <<EOF
{
    "post_id": "$post_id",
    "user_id": "$user_id",
    "event_type": "$event_type",
    "timestamp": "$timestamp"
}
EOF
)
    
    make_request "/api/events/interaction" "$data"
}

# Generate view event
create_view() {
    local post_id=$1
    local user_id=$2
    local platform=$3
    local duration=$4
    local timestamp=$(get_timestamp)
    
    local data=$(cat <<EOF
{
    "post_id": "$post_id",
    "user_id": "$user_id",
    "viewed_at": "$timestamp",
    "duration": $duration,
    "platform": "$platform"
}
EOF
)
    
    make_request "/api/events/view" "$data"
}

# Generate remix event
create_remix() {
    local original_post_id=$1
    local remix_post_id=$2
    local user_id=$3
    local timestamp=$(get_timestamp)
    
    local data=$(cat <<EOF
{
    "original_post_id": "$original_post_id",
    "remix_post_id": "$remix_post_id",
    "user_id": "$user_id",
    "remixed_at": "$timestamp"
}
EOF
)
    
    make_request "/api/events/remix" "$data"
}

# Main test scenarios
main() {
    log_info "Starting Test Data Generator for Confluent Viral Intelligence System"
    log_info "API URL: $API_URL"
    echo ""
    
    # Check if API is reachable
    if ! curl -s -f "${API_URL}/health" > /dev/null 2>&1; then
        log_warning "API health check failed. Make sure the streaming service is running."
        log_info "You can still continue, but requests may fail."
        echo ""
    else
        log_success "API is reachable"
        echo ""
    fi
    
    # Scenario 1: Create viral content with high engagement
    log_info "=== Scenario 1: Viral Content ==="
    VIRAL_POST="post_viral_001"
    VIRAL_CREATOR="creator_alpha"
    
    log_info "Creating viral video content..."
    create_content "$VIRAL_POST" "$VIRAL_CREATOR" "video" "Epic sunset timelapse over mountain peaks with dramatic clouds"
    sleep 0.5
    
    log_info "Generating high engagement for viral content..."
    # Generate 50 views
    for i in {1..50}; do
        create_view "$VIRAL_POST" "$(get_random_user)" "mobile" $((RANDOM % 60 + 30))
        [ $((i % 10)) -eq 0 ] && log_info "  Generated $i views..."
    done
    
    # Generate 30 likes
    for i in {1..30}; do
        create_interaction "$VIRAL_POST" "$(get_random_user)" "like"
    done
    log_info "  Generated 30 likes"
    
    # Generate 15 comments
    for i in {1..15}; do
        create_interaction "$VIRAL_POST" "$(get_random_user)" "comment"
    done
    log_info "  Generated 15 comments"
    
    # Generate 10 shares
    for i in {1..10}; do
        create_interaction "$VIRAL_POST" "$(get_random_user)" "share"
    done
    log_info "  Generated 10 shares"
    
    log_success "Viral content scenario complete"
    echo ""
    
    # Scenario 2: Create moderate engagement content
    log_info "=== Scenario 2: Moderate Engagement Content ==="
    
    for post_num in {1..5}; do
        POST_ID="post_moderate_$(printf '%03d' $post_num)"
        CREATOR=$(get_random_user)
        
        # Different content types
        CONTENT_TYPES=("image" "video" "music" "voice")
        CONTENT_TYPE="${CONTENT_TYPES[$RANDOM % ${#CONTENT_TYPES[@]}]}"
        
        # Different prompts
        PROMPTS=(
            "Beautiful landscape photography with vibrant colors"
            "Abstract art with geometric patterns"
            "Relaxing ambient music for meditation"
            "Energetic voice narration for podcast intro"
            "Minimalist design with clean lines"
        )
        PROMPT="${PROMPTS[$RANDOM % ${#PROMPTS[@]}]}"
        
        log_info "Creating $CONTENT_TYPE content: $POST_ID"
        create_content "$POST_ID" "$CREATOR" "$CONTENT_TYPE" "$PROMPT"
        sleep 0.3
        
        # Moderate engagement: 10-20 views, 5-10 likes, 2-5 comments, 1-3 shares
        VIEWS=$((RANDOM % 11 + 10))
        LIKES=$((RANDOM % 6 + 5))
        COMMENTS=$((RANDOM % 4 + 2))
        SHARES=$((RANDOM % 3 + 1))
        
        # Generate views
        for i in $(seq 1 $VIEWS); do
            PLATFORM=$([ $((RANDOM % 2)) -eq 0 ] && echo "mobile" || echo "web")
            DURATION=$((RANDOM % 45 + 15))
            create_view "$POST_ID" "$(get_random_user)" "$PLATFORM" "$DURATION"
        done
        
        # Generate likes
        for i in $(seq 1 $LIKES); do
            create_interaction "$POST_ID" "$(get_random_user)" "like"
        done
        
        # Generate comments
        for i in $(seq 1 $COMMENTS); do
            create_interaction "$POST_ID" "$(get_random_user)" "comment"
        done
        
        # Generate shares
        for i in $(seq 1 $SHARES); do
            create_interaction "$POST_ID" "$(get_random_user)" "share"
        done
        
        log_info "  Generated: $VIEWS views, $LIKES likes, $COMMENTS comments, $SHARES shares"
    done
    
    log_success "Moderate engagement scenario complete"
    echo ""
    
    # Scenario 3: Create remix chain
    log_info "=== Scenario 3: Remix Chain ==="
    ORIGINAL_POST="post_original_remix"
    ORIGINAL_CREATOR="creator_beta"
    
    log_info "Creating original content for remix chain..."
    create_content "$ORIGINAL_POST" "$ORIGINAL_CREATOR" "image" "Stunning portrait with dramatic lighting"
    sleep 0.5
    
    # Generate some engagement for original
    for i in {1..15}; do
        create_view "$ORIGINAL_POST" "$(get_random_user)" "mobile" $((RANDOM % 40 + 20))
    done
    for i in {1..8}; do
        create_interaction "$ORIGINAL_POST" "$(get_random_user)" "like"
    done
    
    log_info "Creating remix chain (3 levels)..."
    
    # First level remixes
    REMIX_1_1="post_remix_1_1"
    REMIX_1_2="post_remix_1_2"
    
    create_remix "$ORIGINAL_POST" "$REMIX_1_1" "user_003"
    create_content "$REMIX_1_1" "user_003" "image" "Remix: Added vibrant color grading"
    sleep 0.3
    
    create_remix "$ORIGINAL_POST" "$REMIX_1_2" "user_004"
    create_content "$REMIX_1_2" "user_004" "image" "Remix: Applied vintage filter"
    sleep 0.3
    
    # Add engagement to first level remixes
    for remix in "$REMIX_1_1" "$REMIX_1_2"; do
        for i in {1..10}; do
            create_view "$remix" "$(get_random_user)" "web" $((RANDOM % 35 + 15))
        done
        for i in {1..5}; do
            create_interaction "$remix" "$(get_random_user)" "like"
        done
    done
    
    # Second level remix (remix of a remix)
    REMIX_2_1="post_remix_2_1"
    create_remix "$REMIX_1_1" "$REMIX_2_1" "user_005"
    create_content "$REMIX_2_1" "user_005" "image" "Remix of remix: Added artistic overlay"
    sleep 0.3
    
    # Add engagement to second level remix
    for i in {1..8}; do
        create_view "$REMIX_2_1" "$(get_random_user)" "mobile" $((RANDOM % 30 + 10))
    done
    for i in {1..4}; do
        create_interaction "$REMIX_2_1" "$(get_random_user)" "like"
    done
    
    # Third level remix
    REMIX_3_1="post_remix_3_1"
    create_remix "$REMIX_2_1" "$REMIX_3_1" "user_006"
    create_content "$REMIX_3_1" "user_006" "image" "Deep remix: Complete style transformation"
    sleep 0.3
    
    # Add engagement to third level remix
    for i in {1..6}; do
        create_view "$REMIX_3_1" "$(get_random_user)" "web" $((RANDOM % 25 + 10))
    done
    for i in {1..3}; do
        create_interaction "$REMIX_3_1" "$(get_random_user)" "like"
    done
    
    log_success "Remix chain scenario complete (3 levels deep)"
    echo ""
    
    # Scenario 4: Create low engagement content
    log_info "=== Scenario 4: Low Engagement Content ==="
    
    for post_num in {1..3}; do
        POST_ID="post_low_$(printf '%03d' $post_num)"
        CREATOR=$(get_random_user)
        
        log_info "Creating low engagement content: $POST_ID"
        create_content "$POST_ID" "$CREATOR" "image" "Simple test content"
        sleep 0.3
        
        # Low engagement: 1-3 views, 0-1 likes
        VIEWS=$((RANDOM % 3 + 1))
        LIKES=$((RANDOM % 2))
        
        for i in $(seq 1 $VIEWS); do
            create_view "$POST_ID" "$(get_random_user)" "mobile" $((RANDOM % 20 + 5))
        done
        
        for i in $(seq 1 $LIKES); do
            create_interaction "$POST_ID" "$(get_random_user)" "like"
        done
        
        log_info "  Generated: $VIEWS views, $LIKES likes"
    done
    
    log_success "Low engagement scenario complete"
    echo ""
    
    # Scenario 5: Simulate real-time burst of activity
    log_info "=== Scenario 5: Real-time Activity Burst ==="
    BURST_POST="post_burst_001"
    BURST_CREATOR="creator_gamma"
    
    log_info "Creating content for activity burst..."
    create_content "$BURST_POST" "$BURST_CREATOR" "video" "Breaking: Amazing discovery in AI art generation"
    sleep 0.5
    
    log_info "Simulating rapid engagement burst (30 seconds)..."
    END_TIME=$(($(date +%s) + 30))
    EVENT_COUNT=0
    
    while [ $(date +%s) -lt $END_TIME ]; do
        # Random event type
        EVENT_TYPE=$((RANDOM % 4))
        
        case $EVENT_TYPE in
            0)
                create_view "$BURST_POST" "$(get_random_user)" "mobile" $((RANDOM % 60 + 10))
                ;;
            1)
                create_interaction "$BURST_POST" "$(get_random_user)" "like"
                ;;
            2)
                create_interaction "$BURST_POST" "$(get_random_user)" "comment"
                ;;
            3)
                create_interaction "$BURST_POST" "$(get_random_user)" "share"
                ;;
        esac
        
        EVENT_COUNT=$((EVENT_COUNT + 1))
        sleep 0.5
    done
    
    log_success "Activity burst complete ($EVENT_COUNT events in 30 seconds)"
    echo ""
    
    # Summary
    log_info "=== Test Data Generation Complete ==="
    log_success "Generated test data for:"
    echo "  ✓ 1 viral content with high engagement"
    echo "  ✓ 5 moderate engagement posts"
    echo "  ✓ 1 remix chain (3 levels deep)"
    echo "  ✓ 3 low engagement posts"
    echo "  ✓ 1 real-time activity burst"
    echo ""
    log_info "Next steps:"
    echo "  1. Check Confluent Cloud topics for events"
    echo "  2. Verify Flink jobs are processing"
    echo "  3. Check Firestore for trending scores"
    echo "  4. Open dashboard to see real-time updates"
    echo ""
    log_info "To monitor events in real-time, run:"
    echo "  watch -n 2 'curl -s ${API_URL}/api/analytics/trending?limit=10 | jq'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --api-url URL     Set the API URL (default: http://localhost:8080)"
            echo "  --verbose         Enable verbose output"
            echo "  --help            Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  API_URL           Set the API URL"
            echo "  VERBOSE           Enable verbose output (true/false)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --api-url https://viral-intelligence-streaming-xxxxx.run.app"
            echo "  API_URL=http://localhost:8080 VERBOSE=true $0"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
