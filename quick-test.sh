#!/bin/bash

# Quick Test Script - Tests individual components without full E2E
# Use this for rapid verification during development

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Test 1: Build streaming service
test_build() {
    log_header "Test 1: Build Streaming Service"
    
    cd streaming-service
    
    if go build -o cmd/main cmd/main.go; then
        log_success "Streaming service builds successfully"
        cd ..
        return 0
    else
        log_error "Streaming service build failed"
        cd ..
        return 1
    fi
}

# Test 2: Check configuration
test_config() {
    log_header "Test 2: Configuration Check"
    
    if [ ! -f "streaming-service/.env" ]; then
        log_error ".env file missing"
        return 1
    fi
    
    local required_vars=(
        "CONFLUENT_BOOTSTRAP_SERVERS"
        "CONFLUENT_API_KEY"
        "CONFLUENT_API_SECRET"
        "GOOGLE_CLOUD_PROJECT"
        "FIRESTORE_PROJECT_ID"
    )
    
    local missing=0
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" streaming-service/.env; then
            log_error "Missing required variable: $var"
            missing=1
        fi
    done
    
    if [ $missing -eq 0 ]; then
        log_success "All required configuration variables present"
        return 0
    else
        return 1
    fi
}

# Test 3: Verify test data generator
test_generator() {
    log_header "Test 3: Test Data Generator"
    
    if [ ! -f "test-data-generator/generate_events.sh" ]; then
        log_error "Test data generator not found"
        return 1
    fi
    
    if [ ! -x "test-data-generator/generate_events.sh" ]; then
        log_error "Test data generator not executable"
        return 1
    fi
    
    # Test that the script is syntactically correct
    if bash -n test-data-generator/generate_events.sh; then
        log_success "Test data generator is valid"
        return 0
    else
        log_error "Test data generator has syntax errors"
        return 1
    fi
}

# Test 4: Check dashboard dependencies
test_dashboard_deps() {
    log_header "Test 4: Dashboard Dependencies"
    
    cd dashboard
    
    if [ ! -f "package.json" ]; then
        log_error "package.json not found"
        cd ..
        return 1
    fi
    
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies..."
        if npm install; then
            log_success "Dependencies installed"
            cd ..
            return 0
        else
            log_error "Failed to install dependencies"
            cd ..
            return 1
        fi
    else
        log_success "Dependencies already installed"
        cd ..
        return 0
    fi
}

# Test 5: Verify Go dependencies
test_go_deps() {
    log_header "Test 5: Go Dependencies"
    
    cd streaming-service
    
    if go mod verify; then
        log_success "Go dependencies verified"
        cd ..
        return 0
    else
        log_error "Go dependencies verification failed"
        cd ..
        return 1
    fi
}

# Test 6: Check file structure
test_file_structure() {
    log_header "Test 6: File Structure"
    
    local required_files=(
        "streaming-service/cmd/main.go"
        "streaming-service/internal/config/config.go"
        "streaming-service/internal/models/events.go"
        "streaming-service/internal/services/kafka_producer.go"
        "streaming-service/internal/services/kafka_consumer.go"
        "streaming-service/internal/services/vertexai.go"
        "streaming-service/internal/services/firestore.go"
        "streaming-service/internal/services/event_processor.go"
        "streaming-service/internal/services/websocket.go"
        "streaming-service/internal/handlers/event_handler.go"
        "dashboard/src/App.js"
        "dashboard/package.json"
        "test-data-generator/generate_events.sh"
        "flink-sql/aggregations.sql"
    )
    
    local missing=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Missing file: $file"
            missing=1
        fi
    done
    
    if [ $missing -eq 0 ]; then
        log_success "All required files present"
        return 0
    else
        return 1
    fi
}

# Test 7: Syntax check Go files
test_go_syntax() {
    log_header "Test 7: Go Syntax Check"
    
    cd streaming-service
    
    if go vet ./...; then
        log_success "Go syntax check passed"
        cd ..
        return 0
    else
        log_error "Go syntax check failed"
        cd ..
        return 1
    fi
}

# Test 8: Check dashboard build
test_dashboard_build() {
    log_header "Test 8: Dashboard Build Check"
    
    cd dashboard
    
    log_info "This may take a minute..."
    if npm run build > /dev/null 2>&1; then
        log_success "Dashboard builds successfully"
        cd ..
        return 0
    else
        log_error "Dashboard build failed"
        cd ..
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Confluent Viral Intelligence - Quick Test${NC}"
    echo "Running component tests..."
    echo ""
    
    local passed=0
    local failed=0
    
    # Run tests
    test_file_structure && passed=$((passed+1)) || failed=$((failed+1))
    test_config && passed=$((passed+1)) || failed=$((failed+1))
    test_go_deps && passed=$((passed+1)) || failed=$((failed+1))
    test_build && passed=$((passed+1)) || failed=$((failed+1))
    test_go_syntax && passed=$((passed+1)) || failed=$((failed+1))
    test_generator && passed=$((passed+1)) || failed=$((failed+1))
    test_dashboard_deps && passed=$((passed+1)) || failed=$((failed+1))
    
    # Optional: Dashboard build (takes longer)
    if [ "${SKIP_DASHBOARD_BUILD}" != "true" ]; then
        test_dashboard_build && passed=$((passed+1)) || failed=$((failed+1))
    else
        log_info "Skipping dashboard build (set SKIP_DASHBOARD_BUILD=false to enable)"
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $passed"
    echo -e "${RED}Failed:${NC} $failed"
    echo ""
    
    if [ $failed -eq 0 ]; then
        log_success "All tests passed!"
        echo ""
        echo "System is ready for E2E testing."
        echo "Run: ./e2e-test.sh"
        return 0
    else
        log_error "Some tests failed"
        echo ""
        echo "Fix the issues above before running E2E tests."
        return 1
    fi
}

# Run main
main
