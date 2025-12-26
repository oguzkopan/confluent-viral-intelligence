#!/bin/bash

# Quick CORS Update Script for Viral Intelligence Streaming Service
# This updates only the ALLOWED_ORIGINS environment variable without rebuilding
set -e

# Configuration
PROJECT_ID="yarimai"
SERVICE_NAME="viral-intelligence-streaming"
REGION="us-central1"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Quick CORS Update for Viral Intelligence Service        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLI is not installed${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting GCP project to ${PROJECT_ID}...${NC}"
gcloud config set project ${PROJECT_ID}

# New ALLOWED_ORIGINS value
NEW_ORIGINS="https://viral-intelligence-dashboard.web.app;https://viral-intelligence-dashboard.firebaseapp.com;https://yarimai.web.app;https://yarimai.firebaseapp.com;https://yarimai.com"

echo -e "${YELLOW}Updating ALLOWED_ORIGINS environment variable...${NC}"
echo -e "${BLUE}New origins:${NC}"
echo "${NEW_ORIGINS}" | tr ';' '\n' | sed 's/^/  - /'
echo ""

# Update the environment variable
gcloud run services update ${SERVICE_NAME} \
  --region ${REGION} \
  --update-env-vars "ALLOWED_ORIGINS=${NEW_ORIGINS}"

echo ""
echo -e "${GREEN}✓ CORS configuration updated successfully!${NC}"
echo ""

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')

echo -e "${YELLOW}Testing health endpoint...${NC}"
sleep 3

if curl -f "${SERVICE_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Health check passed!${NC}"
else
    echo -e "${RED}✗ Health check failed. Please check the logs.${NC}"
    echo -e "${YELLOW}View logs with: gcloud run logs read ${SERVICE_NAME} --region ${REGION}${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  CORS Update Complete! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service URL: ${SERVICE_URL}${NC}"
echo -e "${BLUE}Allowed Origins:${NC}"
echo "${NEW_ORIGINS}" | tr ';' '\n' | sed 's/^/  - /'
echo ""
echo -e "${YELLOW}Note: Changes take effect immediately. Test your app at https://yarimai.com${NC}"
echo ""

