#!/bin/bash

# Complete Deployment Script for Viral Intelligence System
# This script deploys both the streaming service and dashboard
#
# Usage:
#   ./deploy-all.sh                    # Interactive mode (asks for confirmation)
#   ./deploy-all.sh --yes              # Auto-deploy everything
#   ./deploy-all.sh --service-only     # Deploy streaming service only
#   ./deploy-all.sh --dashboard-only   # Deploy dashboard only
#   ./deploy-all.sh --skip-service     # Skip streaming service deployment
#   ./deploy-all.sh --skip-dashboard   # Skip dashboard deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="yarimai"
REGION="us-central1"
STREAMING_SERVICE_NAME="viral-intelligence-streaming"

# Parse command line arguments
AUTO_YES=false
DEPLOY_SERVICE=true
DEPLOY_DASHBOARD=true

for arg in "$@"; do
    case $arg in
        --yes|-y)
            AUTO_YES=true
            ;;
        --service-only)
            DEPLOY_SERVICE=true
            DEPLOY_DASHBOARD=false
            AUTO_YES=true
            ;;
        --dashboard-only)
            DEPLOY_SERVICE=false
            DEPLOY_DASHBOARD=true
            AUTO_YES=true
            ;;
        --skip-service)
            DEPLOY_SERVICE=false
            ;;
        --skip-dashboard)
            DEPLOY_DASHBOARD=false
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --yes, -y              Auto-confirm all prompts"
            echo "  --service-only         Deploy streaming service only"
            echo "  --dashboard-only       Deploy dashboard only"
            echo "  --skip-service         Skip streaming service deployment"
            echo "  --skip-dashboard       Skip dashboard deployment"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                     # Interactive mode"
            echo "  $0 --yes               # Deploy everything without prompts"
            echo "  $0 --service-only      # Deploy only streaming service"
            echo "  $0 --dashboard-only    # Deploy only dashboard"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Viral Intelligence System - Complete Deployment         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$AUTO_YES" = true ]; then
    echo -e "${YELLOW}Running in auto-confirm mode${NC}"
    echo ""
fi

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for confirmation
confirm() {
    if [ "$AUTO_YES" = true ]; then
        echo "$1 ... YES (auto-confirmed)"
        return 0
    fi
    
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Check prerequisites
print_section "Checking Prerequisites"

if ! command_exists gcloud; then
    echo -e "${RED}✗ gcloud CLI not found${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
echo -e "${GREEN}✓ gcloud CLI found${NC}"

if ! command_exists firebase; then
    echo -e "${RED}✗ Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI found${NC}"

if ! command_exists node; then
    echo -e "${RED}✗ Node.js not found${NC}"
    echo "Install from: https://nodejs.org/"
    exit 1
fi
echo -e "${GREEN}✓ Node.js found${NC}"

if ! command_exists go; then
    echo -e "${RED}✗ Go not found${NC}"
    echo "Install from: https://golang.org/dl/"
    exit 1
fi
echo -e "${GREEN}✓ Go found${NC}"

# Check if .env file exists for streaming service
print_section "Checking Configuration"

if [ ! -f "streaming-service/.env" ]; then
    echo -e "${RED}✗ streaming-service/.env not found${NC}"
    echo ""
    echo "Please create streaming-service/.env with your Confluent credentials:"
    echo "  cd streaming-service"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your values"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ streaming-service/.env found${NC}"

# Check if Firebase service account key exists
if [ ! -f "streaming-service/firebase-service-account-key.json" ]; then
    echo -e "${YELLOW}⚠ Firebase service account key not found in streaming-service/${NC}"
    if [ -f "../backend/firebase-service-account-key.json" ]; then
        echo -e "${YELLOW}  Copying from backend...${NC}"
        cp ../backend/firebase-service-account-key.json streaming-service/
        echo -e "${GREEN}✓ Copied Firebase service account key${NC}"
    else
        echo -e "${RED}✗ Firebase service account key not found${NC}"
        echo "Please place firebase-service-account-key.json in streaming-service/"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Firebase service account key found${NC}"
fi

# Set GCP project
print_section "Setting GCP Project"
echo -e "${YELLOW}Setting project to: ${PROJECT_ID}${NC}"
gcloud config set project ${PROJECT_ID}
echo -e "${GREEN}✓ Project set${NC}"

# Deploy Streaming Service
print_section "Deploying Streaming Service"

if [ "$DEPLOY_SERVICE" = false ]; then
    echo -e "${YELLOW}⊘ Skipping streaming service deployment (--skip-service or --dashboard-only)${NC}"
    
    # Try to get existing service URL
    SERVICE_URL=$(gcloud run services describe ${STREAMING_SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ]; then
        echo -e "${RED}✗ Could not find existing service URL${NC}"
        echo "Please deploy the streaming service first or remove --skip-service flag."
        exit 1
    fi
    
    echo -e "${GREEN}Using existing service URL: ${SERVICE_URL}${NC}"
    echo "${SERVICE_URL}" > .service-url
elif confirm "Deploy streaming service to Cloud Run?"; then
    echo -e "${YELLOW}Deploying streaming service...${NC}"
    cd streaming-service
    bash deploy.sh
    cd ..
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${STREAMING_SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')
    echo ""
    echo -e "${GREEN}✓ Streaming service deployed${NC}"
    echo -e "${GREEN}  Service URL: ${SERVICE_URL}${NC}"
    echo ""
    
    # Save service URL for dashboard
    echo "${SERVICE_URL}" > .service-url
else
    echo -e "${YELLOW}⊘ Skipping streaming service deployment${NC}"
    
    # Try to get existing service URL
    SERVICE_URL=$(gcloud run services describe ${STREAMING_SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ]; then
        echo -e "${RED}✗ Could not find existing service URL${NC}"
        echo "Please deploy the streaming service first or enter the URL manually."
        exit 1
    fi
    
    echo -e "${GREEN}Using existing service URL: ${SERVICE_URL}${NC}"
    echo "${SERVICE_URL}" > .service-url
fi

# Deploy Dashboard
print_section "Deploying Dashboard"

if [ "$DEPLOY_DASHBOARD" = false ]; then
    echo -e "${YELLOW}⊘ Skipping dashboard deployment (--skip-dashboard or --service-only)${NC}"
elif confirm "Deploy dashboard to Firebase Hosting?"; then
    echo -e "${YELLOW}Preparing dashboard...${NC}"
    cd dashboard
    
    # Update .env.production with service URL
    echo -e "${YELLOW}Updating dashboard configuration...${NC}"
    cat > .env.production << EOF
REACT_APP_API_URL=${SERVICE_URL}
REACT_APP_WS_URL=${SERVICE_URL/https/wss}/ws
EOF
    echo -e "${GREEN}✓ Dashboard configuration updated${NC}"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        npm install
    fi
    
    # Build dashboard
    echo -e "${YELLOW}Building dashboard...${NC}"
    npm run build
    echo -e "${GREEN}✓ Dashboard built${NC}"
    
    # Deploy to Firebase
    echo -e "${YELLOW}Deploying to Firebase Hosting...${NC}"
    echo -e "${YELLOW}  - viral-intelligence-dashboard.web.app${NC}"
    echo -e "${YELLOW}  - yarimai.web.app${NC}"
    firebase deploy --only hosting --project ${PROJECT_ID}
    
    cd ..
    echo -e "${GREEN}✓ Dashboard deployed${NC}"
else
    echo -e "${YELLOW}⊘ Skipping dashboard deployment${NC}"
fi

# Verify Deployment
print_section "Verifying Deployment"

echo -e "${YELLOW}Testing streaming service health...${NC}"
if curl -f "${SERVICE_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Streaming service is healthy${NC}"
else
    echo -e "${RED}✗ Streaming service health check failed${NC}"
    echo "Check logs with: gcloud run logs read ${STREAMING_SERVICE_NAME} --region ${REGION}"
fi

echo ""
echo -e "${YELLOW}Testing trending endpoint...${NC}"
if curl -f "${SERVICE_URL}/api/analytics/trending?limit=5" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Trending endpoint is working${NC}"
else
    echo -e "${YELLOW}⚠ Trending endpoint returned an error (this is normal if no data exists yet)${NC}"
fi

# Summary
print_section "Deployment Summary"

echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo -e "  Streaming Service: ${GREEN}${SERVICE_URL}${NC}"
echo -e "  Dashboard:         ${GREEN}https://yarimai.web.app${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Open dashboard: https://yarimai.web.app"
echo "  2. Verify Confluent topics are receiving messages"
echo "  3. Check Firestore collections for trending data"
echo "  4. Integrate with backend (see COMPLETE_DEPLOYMENT_GUIDE.md)"
echo ""
echo -e "${BLUE}Monitoring:${NC}"
echo "  View logs:    gcloud run logs tail ${STREAMING_SERVICE_NAME} --region ${REGION}"
echo "  View metrics: https://console.cloud.google.com/run/detail/${REGION}/${STREAMING_SERVICE_NAME}/metrics"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  Complete Guide: ./COMPLETE_DEPLOYMENT_GUIDE.md"
echo "  API Docs:       ./API_DOCUMENTATION.md"
echo "  Architecture:   ./ARCHITECTURE.md"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment successful! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
