#!/bin/bash

# Pre-Deployment Checklist Script
# Verifies all prerequisites before production deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-Deployment Checklist${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check 1: Confluent Cloud credentials
log_info "Checking Confluent Cloud configuration..."
if [ -f "streaming-service/.env" ]; then
    source streaming-service/.env
    
    if [ "$CONFLUENT_BOOTSTRAP_SERVERS" != "pkc-xxxxx.us-east-1.aws.confluent.cloud:9092" ] && [ -n "$CONFLUENT_BOOTSTRAP_SERVERS" ]; then
        log_success "Confluent bootstrap servers configured"
    else
        log_error "Confluent bootstrap servers not configured (still has placeholder)"
    fi
    
    if [ "$CONFLUENT_API_KEY" = "U5AZXVJ2MO4TNZQO" ]; then
        log_success "Confluent API key is set"
    else
        log_error "Confluent API key not set correctly"
    fi
    
    if [ "$CONFLUENT_API_SECRET" != "your-secret-here" ] && [ -n "$CONFLUENT_API_SECRET" ]; then
        log_success "Confluent API secret configured"
    else
        log_error "Confluent API secret not configured (still has placeholder)"
    fi
else
    log_error "streaming-service/.env file not found"
fi

# Check 2: Firebase service account
log_info "Checking Firebase service account..."
if [ -f "streaming-service/firebase-service-account-key.json" ]; then
    log_success "Firebase service account key exists"
else
    log_warning "Firebase service account key not found in streaming-service/"
    log_info "  Checking backend directory..."
    if [ -f "../backend/firebase-service-account-key.json" ]; then
        log_success "Firebase service account key found in backend/"
    else
        log_error "Firebase service account key not found"
    fi
fi

# Check 3: Confluent Cloud topics
log_info "Checking if Confluent Cloud topics are created..."
log_warning "Manual verification required - check Confluent Cloud Console"
echo "  Required topics:"
echo "    - user-interactions (6 partitions)"
echo "    - content-metadata (3 partitions)"
echo "    - view-events (6 partitions)"
echo "    - remix-events (3 partitions)"
echo "    - trending-scores (3 partitions)"
echo "    - recommendations (3 partitions)"

# Check 4: Flink compute pool
log_info "Checking Flink setup..."
log_warning "Manual verification required - check Confluent Cloud Console"
echo "  Required:"
echo "    - Flink compute pool created"
echo "    - Flink SQL statements executed"
echo "    - Flink jobs running"

# Check 5: GCP project access
log_info "Checking GCP project access..."
if command -v gcloud &> /dev/null; then
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ "$CURRENT_PROJECT" = "yarimai" ]; then
        log_success "GCP project set to yarimai"
    else
        log_warning "GCP project is set to '$CURRENT_PROJECT', expected 'yarimai'"
    fi
    
    # Check if user is authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_success "GCP authentication active"
    else
        log_error "GCP authentication not active"
    fi
else
    log_error "gcloud CLI not installed"
fi

# Check 6: Firebase CLI
log_info "Checking Firebase CLI..."
if command -v firebase &> /dev/null; then
    log_success "Firebase CLI installed"
    
    # Check if logged in
    if firebase projects:list &> /dev/null; then
        log_success "Firebase authentication active"
    else
        log_error "Firebase authentication not active"
    fi
else
    log_error "Firebase CLI not installed"
fi

# Check 7: Node.js and npm
log_info "Checking Node.js and npm..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js installed ($NODE_VERSION)"
else
    log_error "Node.js not installed"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    log_success "npm installed ($NPM_VERSION)"
else
    log_error "npm not installed"
fi

# Check 8: Dashboard dependencies
log_info "Checking dashboard dependencies..."
if [ -d "dashboard/node_modules" ]; then
    log_success "Dashboard dependencies installed"
else
    log_warning "Dashboard dependencies not installed (will be installed during deployment)"
fi

# Check 9: Go installation
log_info "Checking Go installation..."
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    log_success "Go installed ($GO_VERSION)"
else
    log_warning "Go not installed locally (not required for Cloud Run deployment)"
fi

# Check 10: Docker (for local testing)
log_info "Checking Docker..."
if command -v docker &> /dev/null; then
    log_success "Docker installed"
else
    log_warning "Docker not installed (not required for Cloud Run deployment)"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Checklist Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Passed: ${CHECKS_PASSED}${NC}"
echo -e "${RED}Failed: ${CHECKS_FAILED}${NC}"
echo -e "${YELLOW}Warnings: ${WARNINGS}${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo -e "${BLUE}You can proceed with deployment:${NC}"
    echo "  ./production-deployment-test.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some critical checks failed!${NC}"
    echo ""
    echo -e "${YELLOW}Please fix the following before deployment:${NC}"
    echo ""
    
    if [ "$CONFLUENT_BOOTSTRAP_SERVERS" = "pkc-xxxxx.us-east-1.aws.confluent.cloud:9092" ]; then
        echo "  1. Update CONFLUENT_BOOTSTRAP_SERVERS in streaming-service/.env"
    fi
    
    if [ "$CONFLUENT_API_SECRET" = "your-secret-here" ]; then
        echo "  2. Update CONFLUENT_API_SECRET in streaming-service/.env"
    fi
    
    if [ ! -f "streaming-service/firebase-service-account-key.json" ] && [ ! -f "../backend/firebase-service-account-key.json" ]; then
        echo "  3. Add firebase-service-account-key.json"
    fi
    
    echo ""
    echo -e "${BLUE}For help, see:${NC}"
    echo "  - SETUP.md"
    echo "  - CONFLUENT_SETUP_GUIDE.md"
    echo ""
    exit 1
fi
