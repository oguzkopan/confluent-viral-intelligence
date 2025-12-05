#!/bin/bash

# Quick System Verification Script
# Checks the current state of all components

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
STREAMING_SERVICE_URL="${STREAMING_SERVICE_URL:-http://localhost:8080}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:3000}"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

section_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check streaming service
check_streaming_service() {
    section_header "Streaming Service"
    
    if curl -s -f "$STREAMING_SERVICE_URL/health" > /dev/null 2>&1; then
        check_pass "Streaming service is running"
        
        # Check API endpoints
        if curl -s -f "$STREAMING_SERVICE_URL/api/analytics/trending?limit=1" > /dev/null 2>&1; then
            check_pass "Trending API endpoint is accessible"
        else
            check_warn "Trending API endpoint returned error (may be empty)"
        fi
    else
        check_fail "Streaming service is not running"
        echo "  Start with: cd streaming-service && ./cmd/main"
    fi
}

# Check dashboard
check_dashboard() {
    section_header "Dashboard"
    
    if curl -s -f "$DASHBOARD_URL" > /dev/null 2>&1; then
        check_pass "Dashboard is running"
    else
        check_fail "Dashboard is not running"
        echo "  Start with: cd dashboard && npm start"
    fi
}

# Check configuration files
check_configuration() {
    section_header "Configuration"
    
    if [ -f "streaming-service/.env" ]; then
        check_pass "Streaming service .env file exists"
        
        # Check for required variables
        if grep -q "CONFLUENT_BOOTSTRAP_SERVERS" streaming-service/.env; then
            check_pass "Confluent bootstrap servers configured"
        else
            check_fail "Confluent bootstrap servers not configured"
        fi
        
        if grep -q "CONFLUENT_API_KEY" streaming-service/.env; then
            check_pass "Confluent API key configured"
        else
            check_fail "Confluent API key not configured"
        fi
        
        if grep -q "GOOGLE_CLOUD_PROJECT" streaming-service/.env; then
            check_pass "Google Cloud project configured"
        else
            check_fail "Google Cloud project not configured"
        fi
    else
        check_fail "Streaming service .env file missing"
        echo "  Copy from: streaming-service/.env.example"
    fi
    
    if [ -f "streaming-service/firebase-service-account-key.json" ] || [ -f "../../backend/firebase-service-account-key.json" ]; then
        check_pass "Firebase service account key exists"
    else
        check_warn "Firebase service account key not found"
    fi
}

# Check dependencies
check_dependencies() {
    section_header "Dependencies"
    
    if command -v go &> /dev/null; then
        check_pass "Go is installed ($(go version | awk '{print $3}'))"
    else
        check_fail "Go is not installed"
    fi
    
    if command -v node &> /dev/null; then
        check_pass "Node.js is installed ($(node --version))"
    else
        check_fail "Node.js is not installed"
    fi
    
    if command -v npm &> /dev/null; then
        check_pass "npm is installed ($(npm --version))"
    else
        check_fail "npm is not installed"
    fi
    
    if command -v curl &> /dev/null; then
        check_pass "curl is installed"
    else
        check_fail "curl is not installed"
    fi
    
    if command -v jq &> /dev/null; then
        check_pass "jq is installed"
    else
        check_warn "jq is not installed (optional, for JSON formatting)"
    fi
}

# Check build artifacts
check_build_artifacts() {
    section_header "Build Artifacts"
    
    if [ -f "streaming-service/cmd/main" ]; then
        check_pass "Streaming service binary exists"
    else
        check_warn "Streaming service binary not found"
        echo "  Build with: cd streaming-service && go build -o cmd/main cmd/main.go"
    fi
    
    if [ -d "dashboard/node_modules" ]; then
        check_pass "Dashboard dependencies installed"
    else
        check_warn "Dashboard dependencies not installed"
        echo "  Install with: cd dashboard && npm install"
    fi
}

# Check test data generator
check_test_generator() {
    section_header "Test Data Generator"
    
    if [ -f "test-data-generator/generate_events.sh" ]; then
        check_pass "Test data generator exists"
        
        if [ -x "test-data-generator/generate_events.sh" ]; then
            check_pass "Test data generator is executable"
        else
            check_warn "Test data generator is not executable"
            echo "  Fix with: chmod +x test-data-generator/generate_events.sh"
        fi
    else
        check_fail "Test data generator not found"
    fi
}

# Check recent data
check_recent_data() {
    section_header "Recent Data"
    
    if curl -s -f "$STREAMING_SERVICE_URL/api/analytics/trending?limit=5" > /dev/null 2>&1; then
        local response=$(curl -s "$STREAMING_SERVICE_URL/api/analytics/trending?limit=5")
        local count=$(echo "$response" | jq '. | length' 2>/dev/null || echo "0")
        
        if [ "$count" -gt 0 ]; then
            check_pass "Found $count trending posts"
            
            if command -v jq &> /dev/null; then
                echo ""
                echo "Top trending posts:"
                echo "$response" | jq -r '.[] | "  - \(.post_id): score=\(.score), viral_prob=\(.viral_probability)"' 2>/dev/null || echo "$response"
            fi
        else
            check_warn "No trending posts found (system may be new)"
            echo "  Generate test data with: bash test-data-generator/generate_events.sh"
        fi
    else
        check_warn "Cannot fetch trending data (service may not be running)"
    fi
}

# Check logs
check_logs() {
    section_header "Logs"
    
    if [ -f "streaming-service.log" ]; then
        local error_count=$(grep -i "error" streaming-service.log | wc -l | tr -d ' ')
        if [ "$error_count" -eq 0 ]; then
            check_pass "No errors in streaming service log"
        else
            check_warn "Found $error_count error(s) in streaming service log"
            echo "  View with: tail -20 streaming-service.log"
        fi
    else
        check_warn "Streaming service log not found (service may not have been started)"
    fi
    
    if [ -f "dashboard.log" ]; then
        local error_count=$(grep -i "error" dashboard.log | wc -l | tr -d ' ')
        if [ "$error_count" -eq 0 ]; then
            check_pass "No errors in dashboard log"
        else
            check_warn "Found $error_count error(s) in dashboard log"
            echo "  View with: tail -20 dashboard.log"
        fi
    else
        check_warn "Dashboard log not found (dashboard may not have been started)"
    fi
}

# Display summary
display_summary() {
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $PASSED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${RED}Failed:${NC} $FAILED"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        if [ $WARNINGS -eq 0 ]; then
            echo -e "${GREEN}✓ All checks passed!${NC}"
            echo ""
            echo "System is ready for testing."
            echo "Run: ./e2e-test.sh"
        else
            echo -e "${YELLOW}⚠ System is mostly ready, but has some warnings${NC}"
            echo ""
            echo "Review warnings above and fix if needed."
            echo "You can still run: ./e2e-test.sh"
        fi
    else
        echo -e "${RED}✗ System has issues that need to be fixed${NC}"
        echo ""
        echo "Fix the failed checks above before running tests."
    fi
    
    echo ""
    echo "Useful commands:"
    echo "  ./e2e-test.sh                    # Run full end-to-end test"
    echo "  bash test-data-generator/generate_events.sh  # Generate test data"
    echo "  tail -f streaming-service.log    # View streaming service logs"
    echo "  tail -f dashboard.log            # View dashboard logs"
}

# Main execution
main() {
    echo -e "${BLUE}Confluent Viral Intelligence - System Verification${NC}"
    echo "Checking system status..."
    
    check_dependencies
    check_configuration
    check_build_artifacts
    check_test_generator
    check_streaming_service
    check_dashboard
    check_recent_data
    check_logs
    
    display_summary
}

# Run main function
main
