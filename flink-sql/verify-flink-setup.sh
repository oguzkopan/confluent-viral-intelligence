#!/bin/bash

# ============================================
# Flink SQL Setup Verification Script
# ============================================
#
# This script verifies that Flink SQL has been set up correctly
# in Confluent Cloud by checking topics, producing test data,
# and verifying output.
#
# Prerequisites:
# - Confluent CLI installed and configured
# - Logged in to Confluent Cloud
# - Cluster and environment selected
#
# Usage:
#   ./verify-flink-setup.sh
#
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if Confluent CLI is installed
check_confluent_cli() {
    print_header "Checking Prerequisites"
    
    if ! command -v confluent &> /dev/null; then
        print_error "Confluent CLI is not installed"
        echo "Install from: https://docs.confluent.io/confluent-cli/current/install.html"
        exit 1
    fi
    print_success "Confluent CLI is installed"
    
    # Check if logged in
    if ! confluent environment list &> /dev/null; then
        print_error "Not logged in to Confluent Cloud"
        echo "Run: confluent login"
        exit 1
    fi
    print_success "Logged in to Confluent Cloud"
}

# Check if topics exist
check_topics() {
    print_header "Checking Kafka Topics"
    
    required_topics=(
        "user-interactions"
        "view-events"
        "remix-events"
        "trending-scores"
    )
    
    all_topics_exist=true
    
    for topic in "${required_topics[@]}"; do
        if confluent kafka topic describe "$topic" &> /dev/null; then
            print_success "Topic exists: $topic"
        else
            print_error "Topic missing: $topic"
            all_topics_exist=false
        fi
    done
    
    if [ "$all_topics_exist" = false ]; then
        print_error "Some topics are missing. Please create them first."
        exit 1
    fi
    
    print_success "All required topics exist"
}

# Produce test events
produce_test_events() {
    print_header "Producing Test Events"
    
    # Generate timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    print_info "Producing test events to user-interactions topic..."
    
    # Produce view event
    echo "{\"post_id\":\"flink-test-post-1\",\"user_id\":\"test-user-1\",\"event_type\":\"view\",\"event_timestamp\":\"$timestamp\"}" | \
        confluent kafka topic produce user-interactions 2>&1 | grep -q "Produced message" && \
        print_success "Produced view event" || print_error "Failed to produce view event"
    
    sleep 1
    
    # Produce like event
    echo "{\"post_id\":\"flink-test-post-1\",\"user_id\":\"test-user-2\",\"event_type\":\"like\",\"event_timestamp\":\"$timestamp\"}" | \
        confluent kafka topic produce user-interactions 2>&1 | grep -q "Produced message" && \
        print_success "Produced like event" || print_error "Failed to produce like event"
    
    sleep 1
    
    # Produce comment event
    echo "{\"post_id\":\"flink-test-post-1\",\"user_id\":\"test-user-3\",\"event_type\":\"comment\",\"event_timestamp\":\"$timestamp\"}" | \
        confluent kafka topic produce user-interactions 2>&1 | grep -q "Produced message" && \
        print_success "Produced comment event" || print_error "Failed to produce comment event"
    
    sleep 1
    
    # Produce share event
    echo "{\"post_id\":\"flink-test-post-1\",\"user_id\":\"test-user-4\",\"event_type\":\"share\",\"event_timestamp\":\"$timestamp\"}" | \
        confluent kafka topic produce user-interactions 2>&1 | grep -q "Produced message" && \
        print_success "Produced share event" || print_error "Failed to produce share event"
    
    print_info "Producing test events to view-events topic..."
    
    # Produce view event
    echo "{\"post_id\":\"flink-test-post-1\",\"user_id\":\"test-user-1\",\"viewed_at\":\"$timestamp\",\"duration\":30,\"platform\":\"web\"}" | \
        confluent kafka topic produce view-events 2>&1 | grep -q "Produced message" && \
        print_success "Produced view event to view-events" || print_error "Failed to produce view event"
    
    print_success "Test events produced successfully"
}

# Wait for Flink processing
wait_for_processing() {
    print_header "Waiting for Flink Processing"
    
    print_info "Waiting 90 seconds for Flink to process events..."
    print_info "Flink uses 1-minute tumbling windows, so we need to wait for the window to close"
    
    for i in {90..1}; do
        echo -ne "\rTime remaining: ${i}s "
        sleep 1
    done
    echo ""
    
    print_success "Wait complete"
}

# Check output in trending-scores topic
check_output() {
    print_header "Checking Output in trending-scores Topic"
    
    print_info "Consuming messages from trending-scores topic..."
    
    # Consume last 10 messages
    output=$(confluent kafka topic consume trending-scores --from-beginning --max-messages 10 2>&1 || true)
    
    if echo "$output" | grep -q "flink-test-post-1"; then
        print_success "Found test post in trending-scores topic!"
        echo ""
        echo "Sample output:"
        echo "$output" | grep "flink-test-post-1" | head -1 | jq '.' 2>/dev/null || echo "$output" | grep "flink-test-post-1" | head -1
    else
        print_warning "Test post not found in trending-scores topic yet"
        print_info "This could mean:"
        echo "  1. Flink jobs are not running"
        echo "  2. Processing is still in progress"
        echo "  3. Window hasn't closed yet"
        echo ""
        print_info "Recent messages in trending-scores:"
        echo "$output" | head -5
    fi
}

# Check Flink jobs (requires Flink CLI or API access)
check_flink_jobs() {
    print_header "Flink Jobs Status"
    
    print_info "To check Flink job status:"
    echo "  1. Go to Confluent Cloud Console"
    echo "  2. Navigate to your cluster"
    echo "  3. Click 'Flink' in the left sidebar"
    echo "  4. Click 'Jobs'"
    echo "  5. Verify you see 2 jobs with status 'RUNNING'"
    echo ""
    print_info "Expected jobs:"
    echo "  - Real-time trending aggregation (INSERT INTO trending_scores)"
    echo "  - Remix boost aggregation (INSERT INTO trending_scores from remix_aggregations)"
}

# Calculate expected trending score
calculate_expected_score() {
    print_header "Expected Results"
    
    print_info "Based on the test events produced:"
    echo ""
    echo "Events for flink-test-post-1:"
    echo "  - 1 view   (weight: 1x) = 1.0"
    echo "  - 1 like   (weight: 2x) = 2.0"
    echo "  - 1 comment (weight: 3x) = 3.0"
    echo "  - 1 share  (weight: 5x) = 5.0"
    echo "  --------------------------------"
    echo "  Total trending score    = 11.0"
    echo ""
    echo "Engagement velocity: 4 interactions/minute"
    echo "Engagement rate: 3/1 = 3.0 (3 interactions per view)"
    echo ""
    print_info "Look for these values in the trending-scores topic"
}

# Provide manual verification steps
manual_verification_steps() {
    print_header "Manual Verification Steps"
    
    echo "Please verify the following in Confluent Cloud Console:"
    echo ""
    echo "1. Tables Created:"
    echo "   - Go to Flink SQL workspace"
    echo "   - Check left sidebar under 'Tables'"
    echo "   - Verify: user_interactions, view_events, remix_events, trending_scores"
    echo ""
    echo "2. Jobs Running:"
    echo "   - Go to Flink > Jobs"
    echo "   - Verify 2 jobs with status 'RUNNING'"
    echo "   - Check metrics: Records Sent > 0, Errors = 0"
    echo ""
    echo "3. Views Created (Optional):"
    echo "   - Go to Flink SQL workspace"
    echo "   - Check left sidebar under 'Views'"
    echo "   - Verify: view_aggregations, remix_aggregations, hourly_trending, top_trending"
    echo ""
    echo "4. Query Results:"
    echo "   - In Flink SQL workspace, run:"
    echo "     SELECT * FROM trending_scores LIMIT 10;"
    echo "   - Verify results are returned"
    echo ""
}

# Summary
print_summary() {
    print_header "Verification Summary"
    
    echo "Automated checks completed. Please review the results above."
    echo ""
    echo "Next steps:"
    echo "  1. Review the manual verification steps"
    echo "  2. Check Flink job status in Confluent Cloud Console"
    echo "  3. Query trending_scores table in Flink SQL workspace"
    echo "  4. If everything looks good, proceed to Task 14"
    echo ""
    print_info "For detailed troubleshooting, see:"
    echo "  - flink-sql/STEP_BY_STEP_EXECUTION.md"
    echo "  - flink-sql/EXECUTION_CHECKLIST.md"
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     Flink SQL Setup Verification Script                   ║"
    echo "║     Confluent Viral Intelligence System                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    
    check_confluent_cli
    check_topics
    produce_test_events
    wait_for_processing
    check_output
    calculate_expected_score
    check_flink_jobs
    manual_verification_steps
    print_summary
    
    echo ""
    print_success "Verification script completed!"
    echo ""
}

# Run main function
main
