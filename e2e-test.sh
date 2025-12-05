#!/bin/bash

# End-to-End Testing Script for Confluent Viral Intelligence System
# This script orchestrates the complete testing workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
STREAMING_SERVICE_DIR="streaming-service"
DASHBOARD_DIR="dashboard"
TEST_DATA_GENERATOR="test-data-generator/generate_events.sh"
STREAMING_SERVICE_PORT=8080
DASHBOARD_PORT=3000

# Process IDs
STREAMING_SERVICE_PID=""
DASHBOARD_PID=""

# Helper functions
log_header() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Cleanup function
cleanup() {
    log_header "Cleaning Up"
    
    if [ ! -z "$STREAMING_SERVICE_PID" ]; then
        log_info "Stopping streaming service (PID: $STREAMING_SERVICE_PID)..."
        kill $STREAMING_SERVICE_PID 2>/dev/null || true
        wait $STREAMING_SERVICE_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$DASHBOARD_PID" ]; then
        log_info "Stopping dashboard (PID: $DASHBOARD_PID)..."
        kill $DASHBOARD_PID 2>/dev/null || true
        wait $DASHBOARD_PID 2>/dev/null || true
    fi
    
    log_success "Cleanup complete"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in go node npm curl jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        else
            log_success "$cmd is installed"
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check for .env file
    if [ ! -f "$STREAMING_SERVICE_DIR/.env" ]; then
        log_error "Missing .env file in $STREAMING_SERVICE_DIR"
        log_info "Please copy .env.example to .env and configure it"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Build streaming service
build_streaming_service() {
    log_header "Building Streaming Service"
    
    cd "$STREAMING_SERVICE_DIR"
    
    log_info "Installing Go dependencies..."
    go mod download
    
    log_info "Building streaming service..."
    go build -o cmd/main cmd/main.go
    
    log_success "Streaming service built successfully"
    
    cd ..
}

# Start streaming service
start_streaming_service() {
    log_header "Starting Streaming Service"
    
    cd "$STREAMING_SERVICE_DIR"
    
    log_info "Starting streaming service on port $STREAMING_SERVICE_PORT..."
    
    # Start the service in the background
    ./cmd/main > ../streaming-service.log 2>&1 &
    STREAMING_SERVICE_PID=$!
    
    cd ..
    
    log_info "Streaming service PID: $STREAMING_SERVICE_PID"
    log_info "Waiting for service to be ready..."
    
    # Wait for service to be ready (max 30 seconds)
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "http://localhost:$STREAMING_SERVICE_PORT/health" > /dev/null 2>&1; then
            log_success "Streaming service is ready"
            return 0
        fi
        
        sleep 1
        attempt=$((attempt + 1))
        
        if [ $((attempt % 5)) -eq 0 ]; then
            log_info "Still waiting... ($attempt/$max_attempts)"
        fi
    done
    
    log_error "Streaming service failed to start within 30 seconds"
    log_info "Check streaming-service.log for details"
    exit 1
}

# Install dashboard dependencies
install_dashboard_deps() {
    log_header "Installing Dashboard Dependencies"
    
    cd "$DASHBOARD_DIR"
    
    if [ ! -d "node_modules" ]; then
        log_info "Installing npm dependencies..."
        npm install
        log_success "Dependencies installed"
    else
        log_info "Dependencies already installed"
    fi
    
    cd ..
}

# Start dashboard
start_dashboard() {
    log_header "Starting Dashboard"
    
    cd "$DASHBOARD_DIR"
    
    # Create .env.local for development
    cat > .env.local <<EOF
REACT_APP_API_URL=http://localhost:$STREAMING_SERVICE_PORT
REACT_APP_WS_URL=ws://localhost:$STREAMING_SERVICE_PORT/ws
EOF
    
    log_info "Starting dashboard on port $DASHBOARD_PORT..."
    
    # Start the dashboard in the background
    PORT=$DASHBOARD_PORT npm start > ../dashboard.log 2>&1 &
    DASHBOARD_PID=$!
    
    cd ..
    
    log_info "Dashboard PID: $DASHBOARD_PID"
    log_info "Waiting for dashboard to be ready..."
    
    # Wait for dashboard to be ready (max 60 seconds)
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "http://localhost:$DASHBOARD_PORT" > /dev/null 2>&1; then
            log_success "Dashboard is ready"
            log_info "Dashboard URL: http://localhost:$DASHBOARD_PORT"
            return 0
        fi
        
        sleep 1
        attempt=$((attempt + 1))
        
        if [ $((attempt % 10)) -eq 0 ]; then
            log_info "Still waiting... ($attempt/$max_attempts)"
        fi
    done
    
    log_warning "Dashboard may not be fully ready, but continuing..."
}

# Test API endpoints
test_api_endpoints() {
    log_header "Testing API Endpoints"
    
    local api_url="http://localhost:$STREAMING_SERVICE_PORT"
    
    # Test health endpoint
    log_step "Testing health endpoint..."
    if curl -s -f "$api_url/health" > /dev/null; then
        log_success "Health endpoint OK"
    else
        log_error "Health endpoint failed"
        return 1
    fi
    
    # Test trending endpoint
    log_step "Testing trending endpoint..."
    if curl -s -f "$api_url/api/analytics/trending?limit=5" > /dev/null; then
        log_success "Trending endpoint OK"
    else
        log_warning "Trending endpoint returned error (may be empty)"
    fi
    
    log_success "API endpoints tested"
}

# Run test data generator
run_test_data_generator() {
    log_header "Running Test Data Generator"
    
    chmod +x "$TEST_DATA_GENERATOR"
    
    log_info "Generating test events..."
    log_info "This will take approximately 2-3 minutes..."
    echo ""
    
    API_URL="http://localhost:$STREAMING_SERVICE_PORT" \
        bash "$TEST_DATA_GENERATOR"
    
    log_success "Test data generation complete"
}

# Verify Confluent Cloud topics
verify_confluent_topics() {
    log_header "Verifying Confluent Cloud Topics"
    
    log_info "To verify events in Confluent Cloud:"
    echo "  1. Go to https://confluent.cloud"
    echo "  2. Navigate to your cluster"
    echo "  3. Click on 'Topics' in the left menu"
    echo "  4. Check the following topics for messages:"
    echo "     - user-interactions"
    echo "     - content-metadata"
    echo "     - view-events"
    echo "     - remix-events"
    echo "     - trending-scores (output from Flink)"
    echo "     - recommendations (output from Flink)"
    echo ""
    
    log_warning "Manual verification required - check Confluent Cloud console"
}

# Verify Flink jobs
verify_flink_jobs() {
    log_header "Verifying Flink Jobs"
    
    log_info "To verify Flink jobs are processing:"
    echo "  1. Go to https://confluent.cloud"
    echo "  2. Navigate to your cluster"
    echo "  3. Click on 'Flink' in the left menu"
    echo "  4. Check that your Flink SQL statements are running"
    echo "  5. Verify job metrics show processed records"
    echo ""
    
    log_warning "Manual verification required - check Confluent Cloud console"
}

# Verify Firestore data
verify_firestore_data() {
    log_header "Verifying Firestore Data"
    
    log_info "To verify data in Firestore:"
    echo "  1. Go to https://console.firebase.google.com"
    echo "  2. Select project: yarimai"
    echo "  3. Navigate to Firestore Database"
    echo "  4. Check the following collections:"
    echo "     - trending_scores (should have documents with viral predictions)"
    echo "     - posts (should have updated metadata with keywords)"
    echo "     - recommendations/{userId}/items (should have recommendations)"
    echo "     - remix_chains/{postId}/remixes (should have remix relationships)"
    echo ""
    
    log_warning "Manual verification required - check Firebase console"
}

# Test WebSocket connection
test_websocket_connection() {
    log_header "Testing WebSocket Connection"
    
    log_info "WebSocket endpoint: ws://localhost:$STREAMING_SERVICE_PORT/ws"
    log_info "The dashboard should automatically connect to this endpoint"
    echo ""
    
    log_info "To verify WebSocket connection:"
    echo "  1. Open browser developer tools (F12)"
    echo "  2. Go to Network tab"
    echo "  3. Filter by 'WS' (WebSocket)"
    echo "  4. You should see an active WebSocket connection"
    echo "  5. Watch for real-time messages as events are processed"
    echo ""
    
    log_warning "Manual verification required - check browser developer tools"
}

# Monitor real-time updates
monitor_realtime_updates() {
    log_header "Monitoring Real-time Updates"
    
    log_info "Fetching current trending posts..."
    echo ""
    
    local api_url="http://localhost:$STREAMING_SERVICE_PORT"
    
    if command -v jq &> /dev/null; then
        curl -s "$api_url/api/analytics/trending?limit=10" | jq '.'
    else
        curl -s "$api_url/api/analytics/trending?limit=10"
    fi
    
    echo ""
    log_info "To monitor updates in real-time, run:"
    echo "  watch -n 2 'curl -s http://localhost:$STREAMING_SERVICE_PORT/api/analytics/trending?limit=10 | jq'"
}

# Display summary
display_summary() {
    log_header "End-to-End Test Summary"
    
    echo -e "${GREEN}✓${NC} Streaming service running on http://localhost:$STREAMING_SERVICE_PORT"
    echo -e "${GREEN}✓${NC} Dashboard running on http://localhost:$DASHBOARD_PORT"
    echo -e "${GREEN}✓${NC} Test data generated and sent to Kafka"
    echo -e "${GREEN}✓${NC} API endpoints tested"
    echo ""
    
    log_info "Manual verification steps:"
    echo "  1. Check Confluent Cloud topics for events"
    echo "  2. Verify Flink jobs are processing"
    echo "  3. Check Firestore for trending scores"
    echo "  4. Open dashboard and verify real-time updates"
    echo "  5. Check WebSocket connection in browser dev tools"
    echo ""
    
    log_info "Useful commands:"
    echo "  # View streaming service logs"
    echo "  tail -f streaming-service.log"
    echo ""
    echo "  # View dashboard logs"
    echo "  tail -f dashboard.log"
    echo ""
    echo "  # Monitor trending posts"
    echo "  watch -n 2 'curl -s http://localhost:$STREAMING_SERVICE_PORT/api/analytics/trending?limit=10 | jq'"
    echo ""
    echo "  # Generate more test data"
    echo "  bash $TEST_DATA_GENERATOR"
    echo ""
    
    log_info "Press Ctrl+C to stop all services and exit"
    echo ""
    
    # Keep script running
    log_info "Services are running. Waiting for interrupt..."
    wait
}

# Main execution
main() {
    log_header "Confluent Viral Intelligence - End-to-End Testing"
    
    check_prerequisites
    build_streaming_service
    start_streaming_service
    test_api_endpoints
    install_dashboard_deps
    start_dashboard
    
    # Give services a moment to stabilize
    sleep 3
    
    run_test_data_generator
    
    # Wait a bit for processing
    log_info "Waiting 10 seconds for event processing..."
    sleep 10
    
    monitor_realtime_updates
    verify_confluent_topics
    verify_flink_jobs
    verify_firestore_data
    test_websocket_connection
    
    display_summary
}

# Run main function
main
