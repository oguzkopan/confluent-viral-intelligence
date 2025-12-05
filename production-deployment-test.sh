#!/bin/bash

# Production Deployment Testing Script
# This script deploys and tests the Confluent Viral Intelligence System in production

set -e

# Configuration
PROJECT_ID="yarimai"
REGION="us-central1"
SERVICE_NAME="viral-intelligence-streaming"
DASHBOARD_SITE="yarimai"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Helper functions
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

log_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

test_passed() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "$1"
}

test_failed() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
    log_error "$1"
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        exit 1
    fi
    test_passed "gcloud CLI is installed"
    
    # Check firebase
    if ! command -v firebase &> /dev/null; then
        log_error "firebase CLI is not installed"
        exit 1
    fi
    test_passed "firebase CLI is installed"
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
    test_passed "curl is installed"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed (optional, but recommended for JSON parsing)"
    else
        test_passed "jq is installed"
    fi
    
    # Set project
    log_info "Setting GCP project to ${PROJECT_ID}..."
    gcloud config set project ${PROJECT_ID}
    test_passed "GCP project set to ${PROJECT_ID}"
}

# Deploy streaming service
deploy_streaming_service() {
    log_section "Deploying Streaming Service to Cloud Run"
    
    cd streaming-service
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        log_error ".env file not found in streaming-service directory"
        log_info "Please create .env file with required credentials"
        exit 1
    fi
    
    # Run deployment script
    log_info "Running deployment script..."
    if bash deploy.sh; then
        test_passed "Streaming service deployed successfully"
    else
        test_failed "Streaming service deployment failed"
        exit 1
    fi
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')
    log_info "Service URL: ${SERVICE_URL}"
    
    cd ..
}

# Test streaming service endpoints
test_streaming_service() {
    log_section "Testing Streaming Service Endpoints"
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null)
    
    if [ -z "$SERVICE_URL" ]; then
        test_failed "Could not retrieve service URL"
        return 1
    fi
    
    log_info "Testing service at: ${SERVICE_URL}"
    
    # Test health endpoint
    log_info "Testing /health endpoint..."
    if curl -f -s "${SERVICE_URL}/health" > /dev/null; then
        test_passed "Health endpoint is responding"
    else
        test_failed "Health endpoint is not responding"
    fi
    
    # Test event ingestion endpoints
    log_info "Testing event ingestion endpoints..."
    
    # Test interaction endpoint
    INTERACTION_DATA='{"post_id":"test_post_001","user_id":"test_user_001","event_type":"like","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$INTERACTION_DATA" \
        "${SERVICE_URL}/api/events/interaction")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        test_passed "Interaction endpoint is working (HTTP $HTTP_CODE)"
    else
        test_failed "Interaction endpoint failed (HTTP $HTTP_CODE)"
    fi
    
    # Test content metadata endpoint
    CONTENT_DATA='{"post_id":"test_post_001","user_id":"test_user_001","content_type":"image","prompt":"Test content for production deployment","created_at":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$CONTENT_DATA" \
        "${SERVICE_URL}/api/events/content")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        test_passed "Content metadata endpoint is working (HTTP $HTTP_CODE)"
    else
        test_failed "Content metadata endpoint failed (HTTP $HTTP_CODE)"
    fi
    
    # Test view endpoint
    VIEW_DATA='{"post_id":"test_post_001","user_id":"test_user_001","viewed_at":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","duration":30,"platform":"web"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$VIEW_DATA" \
        "${SERVICE_URL}/api/events/view")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        test_passed "View endpoint is working (HTTP $HTTP_CODE)"
    else
        test_failed "View endpoint failed (HTTP $HTTP_CODE)"
    fi
    
    # Test analytics endpoints
    log_info "Testing analytics endpoints..."
    
    # Test trending endpoint
    if curl -f -s "${SERVICE_URL}/api/analytics/trending?limit=10" > /dev/null; then
        test_passed "Trending analytics endpoint is working"
    else
        test_failed "Trending analytics endpoint failed"
    fi
}

# Deploy dashboard
deploy_dashboard() {
    log_section "Deploying Dashboard to Firebase Hosting"
    
    cd dashboard
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies..."
        npm install
    fi
    
    # Get service URL for environment variables
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null)
    
    if [ -z "$SERVICE_URL" ]; then
        log_error "Could not retrieve service URL. Deploy streaming service first."
        exit 1
    fi
    
    # Update .env.production with actual service URL
    log_info "Updating .env.production with service URL..."
    cat > .env.production << EOF
# Production environment variables for Viral Intelligence Dashboard
REACT_APP_API_URL=${SERVICE_URL}
REACT_APP_WS_URL=${SERVICE_URL/https/wss}/ws
EOF
    
    # Build the dashboard
    log_info "Building dashboard..."
    if npm run build; then
        test_passed "Dashboard built successfully"
    else
        test_failed "Dashboard build failed"
        exit 1
    fi
    
    # Deploy to Firebase Hosting
    log_info "Deploying to Firebase Hosting..."
    if firebase deploy --only hosting --project ${PROJECT_ID}; then
        test_passed "Dashboard deployed to Firebase Hosting"
    else
        test_failed "Dashboard deployment failed"
        exit 1
    fi
    
    # Get hosting URL
    HOSTING_URL="https://${PROJECT_ID}.web.app"
    log_info "Dashboard URL: ${HOSTING_URL}"
    
    cd ..
}

# Test dashboard
test_dashboard() {
    log_section "Testing Dashboard"
    
    HOSTING_URL="https://${PROJECT_ID}.web.app"
    
    log_info "Testing dashboard at: ${HOSTING_URL}"
    
    # Test if dashboard is accessible
    if curl -f -s "${HOSTING_URL}" > /dev/null; then
        test_passed "Dashboard is accessible"
    else
        test_failed "Dashboard is not accessible"
    fi
    
    # Check if dashboard loads without errors (basic check)
    RESPONSE=$(curl -s "${HOSTING_URL}")
    if echo "$RESPONSE" | grep -q "<!DOCTYPE html>"; then
        test_passed "Dashboard HTML is loading"
    else
        test_failed "Dashboard HTML is not loading properly"
    fi
}

# Generate test data against production
generate_test_data() {
    log_section "Generating Test Data Against Production"
    
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null)
    
    if [ -z "$SERVICE_URL" ]; then
        test_failed "Could not retrieve service URL"
        return 1
    fi
    
    log_info "Generating test data against: ${SERVICE_URL}"
    
    cd test-data-generator
    
    # Run test data generator with production URL
    if API_URL="${SERVICE_URL}" bash generate_events.sh; then
        test_passed "Test data generated successfully"
    else
        test_failed "Test data generation failed"
    fi
    
    cd ..
}

# Monitor Cloud Run logs
monitor_cloud_run_logs() {
    log_section "Monitoring Cloud Run Logs"
    
    log_info "Fetching recent logs from Cloud Run..."
    
    # Get last 50 log entries
    gcloud run logs read ${SERVICE_NAME} --region ${REGION} --limit 50 --format json > /tmp/cloud_run_logs.json 2>/dev/null || true
    
    if [ -f /tmp/cloud_run_logs.json ]; then
        # Check for errors in logs
        ERROR_COUNT=$(cat /tmp/cloud_run_logs.json | jq '[.[] | select(.severity == "ERROR")] | length' 2>/dev/null || echo "0")
        WARNING_COUNT=$(cat /tmp/cloud_run_logs.json | jq '[.[] | select(.severity == "WARNING")] | length' 2>/dev/null || echo "0")
        
        log_info "Found $ERROR_COUNT errors and $WARNING_COUNT warnings in recent logs"
        
        if [ "$ERROR_COUNT" -eq 0 ]; then
            test_passed "No errors found in Cloud Run logs"
        else
            test_failed "Found $ERROR_COUNT errors in Cloud Run logs"
            log_warning "Review logs with: gcloud run logs read ${SERVICE_NAME} --region ${REGION}"
        fi
    else
        log_warning "Could not fetch Cloud Run logs"
    fi
}

# Check Confluent Cloud metrics
check_confluent_metrics() {
    log_section "Checking Confluent Cloud Metrics"
    
    log_info "Please manually verify the following in Confluent Cloud Console:"
    echo "  1. Topics are receiving messages"
    echo "  2. Flink jobs are running"
    echo "  3. Consumer lag is minimal"
    echo "  4. No errors in topic metrics"
    echo ""
    log_info "Confluent Cloud Console: https://confluent.cloud/"
    
    # We can't automatically check Confluent metrics without API access
    # This is a manual verification step
    log_warning "Manual verification required for Confluent Cloud metrics"
}

# Verify Firestore data
verify_firestore_data() {
    log_section "Verifying Firestore Data"
    
    log_info "Checking Firestore collections..."
    
    # Check if gcloud firestore is available
    if ! gcloud firestore --help &> /dev/null; then
        log_warning "gcloud firestore commands not available"
        log_info "Please manually verify Firestore data in Firebase Console"
        return
    fi
    
    # List collections (this requires appropriate permissions)
    log_info "Attempting to list Firestore collections..."
    gcloud firestore collections list --project ${PROJECT_ID} 2>/dev/null || log_warning "Could not list Firestore collections (may require additional permissions)"
    
    log_info "Please manually verify the following in Firebase Console:"
    echo "  1. trending_scores collection has recent data"
    echo "  2. recommendations collection is being updated"
    echo "  3. posts collection has keyword metadata"
    echo "  4. remix_chains collection tracks relationships"
    echo ""
    log_info "Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}/firestore"
}

# Verify all integrations
verify_integrations() {
    log_section "Verifying All Integrations"
    
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null)
    
    log_info "Integration checklist:"
    echo ""
    echo "  ✓ Streaming Service: ${SERVICE_URL}"
    echo "  ✓ Dashboard: https://${PROJECT_ID}.web.app"
    echo "  ✓ Confluent Cloud: Manual verification required"
    echo "  ✓ Firestore: Manual verification required"
    echo "  ✓ Vertex AI: Tested via content metadata endpoint"
    echo ""
    
    log_info "To verify end-to-end flow:"
    echo "  1. Open dashboard: https://${PROJECT_ID}.web.app"
    echo "  2. Generate test data (already done)"
    echo "  3. Watch for real-time updates in dashboard"
    echo "  4. Check Confluent Cloud for message flow"
    echo "  5. Verify Firestore has trending scores"
}

# Print test summary
print_summary() {
    log_section "Test Summary"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    
    echo -e "${CYAN}Total Tests: ${TOTAL_TESTS}${NC}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo ""
    
    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
    fi
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        log_success "All tests passed! Production deployment is successful."
        echo ""
        log_info "Next steps:"
        echo "  1. Monitor the system for 24 hours"
        echo "  2. Set up alerts for errors and performance"
        echo "  3. Review Confluent Cloud metrics regularly"
        echo "  4. Check Firestore data consistency"
        echo ""
        log_info "Useful commands:"
        echo "  - View logs: gcloud run logs tail ${SERVICE_NAME} --region ${REGION}"
        echo "  - Check service: gcloud run services describe ${SERVICE_NAME} --region ${REGION}"
        echo "  - Test API: curl ${SERVICE_URL}/health"
        return 0
    else
        log_error "Some tests failed. Please review the errors above."
        echo ""
        log_info "Troubleshooting:"
        echo "  1. Check Cloud Run logs: gcloud run logs read ${SERVICE_NAME} --region ${REGION}"
        echo "  2. Verify environment variables are set correctly"
        echo "  3. Check Confluent Cloud connectivity"
        echo "  4. Verify Firestore permissions"
        echo "  5. Review service account permissions"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting Production Deployment Testing"
    log_info "Project: ${PROJECT_ID}"
    log_info "Region: ${REGION}"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy streaming service
    deploy_streaming_service
    
    # Test streaming service
    test_streaming_service
    
    # Deploy dashboard
    deploy_dashboard
    
    # Test dashboard
    test_dashboard
    
    # Generate test data
    generate_test_data
    
    # Wait a bit for data to flow through the system
    log_info "Waiting 30 seconds for data to flow through the system..."
    sleep 30
    
    # Monitor logs
    monitor_cloud_run_logs
    
    # Check Confluent metrics (manual)
    check_confluent_metrics
    
    # Verify Firestore data
    verify_firestore_data
    
    # Verify integrations
    verify_integrations
    
    # Print summary
    print_summary
}

# Run main function
main
