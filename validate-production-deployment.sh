#!/bin/bash

# Production Deployment Validation Script
# This script validates that the production deployment is working correctly

set -e

# Configuration
PROJECT_ID="yarimai"
REGION="us-central1"
SERVICE_NAME="viral-intelligence-streaming"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_TESTS=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Get service URL
get_service_url() {
    gcloud run services describe ${SERVICE_NAME} \
        --platform managed \
        --region ${REGION} \
        --format 'value(status.url)' 2>/dev/null || echo ""
}

# Validate Cloud Run deployment
validate_cloud_run() {
    log_section "Validating Cloud Run Deployment"
    
    # Check if service exists
    log_info "Checking if service exists..."
    if gcloud run services describe ${SERVICE_NAME} --region ${REGION} &> /dev/null; then
        log_success "Service exists: ${SERVICE_NAME}"
    else
        log_error "Service not found: ${SERVICE_NAME}"
        return 1
    fi
    
    # Get service URL
    SERVICE_URL=$(get_service_url)
    if [ -z "$SERVICE_URL" ]; then
        log_error "Could not retrieve service URL"
        return 1
    fi
    log_success "Service URL: ${SERVICE_URL}"
    
    # Check service status
    log_info "Checking service status..."
    STATUS=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.conditions[0].status)' 2>/dev/null)
    if [ "$STATUS" = "True" ]; then
        log_success "Service is ready"
    else
        log_error "Service is not ready (status: $STATUS)"
    fi
    
    # Check latest revision
    log_info "Checking latest revision..."
    REVISION=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.latestReadyRevisionName)' 2>/dev/null)
    if [ -n "$REVISION" ]; then
        log_success "Latest revision: ${REVISION}"
    else
        log_warning "Could not determine latest revision"
    fi
    
    # Check instance count
    log_info "Checking instance configuration..."
    MIN_INSTANCES=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(spec.template.metadata.annotations."autoscaling.knative.dev/minScale")' 2>/dev/null)
    MAX_INSTANCES=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(spec.template.metadata.annotations."autoscaling.knative.dev/maxScale")' 2>/dev/null)
    log_info "  Min instances: ${MIN_INSTANCES:-not set}"
    log_info "  Max instances: ${MAX_INSTANCES:-not set}"
    
    if [ "$MIN_INSTANCES" = "1" ] && [ "$MAX_INSTANCES" = "10" ]; then
        log_success "Auto-scaling configured correctly (1-10 instances)"
    else
        log_warning "Auto-scaling may not be configured as expected"
    fi
}

# Test API endpoints
test_api_endpoints() {
    log_section "Testing API Endpoints"
    
    SERVICE_URL=$(get_service_url)
    if [ -z "$SERVICE_URL" ]; then
        log_skip "Service URL not available, skipping API tests"
        return 1
    fi
    
    # Test health endpoint
    log_info "Testing /health endpoint..."
    RESPONSE=$(curl -s -w "\n%{http_code}" "${SERVICE_URL}/health" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Health endpoint responding (HTTP 200)"
        if echo "$BODY" | grep -q "healthy"; then
            log_success "Health check returns healthy status"
        fi
    else
        log_error "Health endpoint failed (HTTP $HTTP_CODE)"
    fi
    
    # Test interaction endpoint
    log_info "Testing /api/events/interaction endpoint..."
    TEST_DATA='{"post_id":"test_validation","user_id":"test_user","event_type":"like","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA" \
        "${SERVICE_URL}/api/events/interaction" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Interaction endpoint responding (HTTP $HTTP_CODE)"
    else
        log_error "Interaction endpoint failed (HTTP $HTTP_CODE)"
    fi
    
    # Test trending endpoint
    log_info "Testing /api/analytics/trending endpoint..."
    RESPONSE=$(curl -s -w "\n%{http_code}" "${SERVICE_URL}/api/analytics/trending?limit=10" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log_success "Trending endpoint responding (HTTP $HTTP_CODE)"
    else
        log_error "Trending endpoint failed (HTTP $HTTP_CODE)"
    fi
}

# Check Cloud Run logs
check_cloud_run_logs() {
    log_section "Checking Cloud Run Logs"
    
    log_info "Fetching recent logs..."
    
    # Get last 50 log entries
    LOGS=$(gcloud run logs read ${SERVICE_NAME} --region ${REGION} --limit 50 2>/dev/null || echo "")
    
    if [ -z "$LOGS" ]; then
        log_warning "Could not fetch logs"
        return
    fi
    
    # Count errors and warnings
    ERROR_COUNT=$(echo "$LOGS" | grep -c "ERROR" || echo "0")
    WARNING_COUNT=$(echo "$LOGS" | grep -c "WARNING" || echo "0")
    
    log_info "Found $ERROR_COUNT errors and $WARNING_COUNT warnings in recent logs"
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        log_success "No errors in recent logs"
    else
        log_error "Found $ERROR_COUNT errors in logs"
        log_info "View logs: gcloud run logs read ${SERVICE_NAME} --region ${REGION}"
    fi
    
    if [ "$WARNING_COUNT" -eq 0 ]; then
        log_success "No warnings in recent logs"
    else
        log_warning "Found $WARNING_COUNT warnings in logs"
    fi
}

# Validate dashboard deployment
validate_dashboard() {
    log_section "Validating Dashboard Deployment"
    
    DASHBOARD_URL="https://${PROJECT_ID}.web.app"
    
    log_info "Testing dashboard at: ${DASHBOARD_URL}"
    
    # Test if dashboard is accessible
    RESPONSE=$(curl -s -w "\n%{http_code}" "${DASHBOARD_URL}" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Dashboard is accessible (HTTP 200)"
        
        # Check if it's HTML
        if echo "$BODY" | grep -q "<!DOCTYPE html>"; then
            log_success "Dashboard HTML is loading"
        else
            log_warning "Dashboard response doesn't look like HTML"
        fi
        
        # Check for React app
        if echo "$BODY" | grep -q "root"; then
            log_success "React app structure detected"
        fi
    else
        log_error "Dashboard is not accessible (HTTP $HTTP_CODE)"
    fi
}

# Check environment configuration
check_environment() {
    log_section "Checking Environment Configuration"
    
    log_info "Checking environment variables..."
    
    # Get environment variables from Cloud Run
    ENV_VARS=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(spec.template.spec.containers[0].env)' 2>/dev/null || echo "")
    
    if [ -z "$ENV_VARS" ]; then
        log_warning "Could not retrieve environment variables"
        return
    fi
    
    # Check for required variables
    REQUIRED_VARS=(
        "CONFLUENT_BOOTSTRAP_SERVERS"
        "CONFLUENT_API_KEY"
        "GOOGLE_CLOUD_PROJECT"
        "FIRESTORE_PROJECT_ID"
        "VERTEX_AI_LOCATION"
    )
    
    for VAR in "${REQUIRED_VARS[@]}"; do
        if echo "$ENV_VARS" | grep -q "$VAR"; then
            log_success "Environment variable set: $VAR"
        else
            log_error "Environment variable missing: $VAR"
        fi
    done
}

# Validate Firestore access
validate_firestore() {
    log_section "Validating Firestore Access"
    
    log_info "Checking Firestore collections..."
    
    # Try to list collections
    if gcloud firestore collections list --project ${PROJECT_ID} &> /dev/null; then
        log_success "Firestore is accessible"
        
        # Check for expected collections
        COLLECTIONS=$(gcloud firestore collections list --project ${PROJECT_ID} 2>/dev/null || echo "")
        
        EXPECTED_COLLECTIONS=("trending_scores" "recommendations" "posts" "remix_chains")
        
        for COLLECTION in "${EXPECTED_COLLECTIONS[@]}"; do
            if echo "$COLLECTIONS" | grep -q "$COLLECTION"; then
                log_success "Collection exists: $COLLECTION"
            else
                log_warning "Collection not found: $COLLECTION (may not have data yet)"
            fi
        done
    else
        log_warning "Could not access Firestore (may require additional permissions)"
        log_info "Verify manually in Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}/firestore"
    fi
}

# Manual verification checklist
manual_verification() {
    log_section "Manual Verification Checklist"
    
    log_info "Please manually verify the following:"
    echo ""
    echo "  Confluent Cloud:"
    echo "    [ ] All 6 topics exist and are receiving messages"
    echo "    [ ] Flink jobs are running without errors"
    echo "    [ ] Consumer lag is minimal (< 100 messages)"
    echo "    [ ] No errors in topic metrics"
    echo ""
    echo "  Dashboard:"
    echo "    [ ] WebSocket connection established"
    echo "    [ ] Real-time updates visible"
    echo "    [ ] Trending posts displayed"
    echo "    [ ] Viral predictions shown"
    echo ""
    echo "  Firestore:"
    echo "    [ ] trending_scores has recent data"
    echo "    [ ] recommendations being updated"
    echo "    [ ] posts have keyword metadata"
    echo "    [ ] remix_chains tracking relationships"
    echo ""
    echo "  Integration:"
    echo "    [ ] Backend can send events"
    echo "    [ ] Mobile app tracking works"
    echo "    [ ] Web app tracking works"
    echo ""
    
    log_info "Confluent Cloud Console: https://confluent.cloud/"
    log_info "Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}"
    log_info "Cloud Run Console: https://console.cloud.google.com/run"
}

# Print summary
print_summary() {
    log_section "Validation Summary"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    
    echo -e "${CYAN}Total Tests: ${TOTAL_TESTS}${NC}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo -e "${YELLOW}Skipped: ${TESTS_SKIPPED}${NC}"
    echo ""
    
    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
    fi
    
    # Calculate success rate
    if [ $((TESTS_PASSED + TESTS_FAILED)) -gt 0 ]; then
        SUCCESS_RATE=$((TESTS_PASSED * 100 / (TESTS_PASSED + TESTS_FAILED)))
        echo -e "${CYAN}Success Rate: ${SUCCESS_RATE}%${NC}"
        echo ""
    fi
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        log_success "All automated tests passed!"
        echo ""
        log_info "Next steps:"
        echo "  1. Complete manual verification checklist above"
        echo "  2. Generate test data: cd test-data-generator && API_URL=\$SERVICE_URL bash generate_events.sh"
        echo "  3. Monitor for 24 hours"
        echo "  4. Set up alerts and monitoring"
        echo ""
        return 0
    else
        log_error "Some tests failed. Please review and fix issues."
        echo ""
        log_info "Troubleshooting:"
        echo "  1. Check logs: gcloud run logs read ${SERVICE_NAME} --region ${REGION}"
        echo "  2. Verify environment variables"
        echo "  3. Check Confluent Cloud connectivity"
        echo "  4. Review PRODUCTION_DEPLOYMENT_GUIDE.md"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting Production Deployment Validation"
    log_info "Project: ${PROJECT_ID}"
    log_info "Region: ${REGION}"
    log_info "Service: ${SERVICE_NAME}"
    echo ""
    
    # Validate Cloud Run
    validate_cloud_run
    
    # Test API endpoints
    test_api_endpoints
    
    # Check logs
    check_cloud_run_logs
    
    # Validate dashboard
    validate_dashboard
    
    # Check environment
    check_environment
    
    # Validate Firestore
    validate_firestore
    
    # Manual verification
    manual_verification
    
    # Print summary
    print_summary
}

# Run main
main
