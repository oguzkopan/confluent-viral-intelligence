#!/bin/bash

# System Status Verification Script
# Checks if all components of the Viral Intelligence system are working

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ID="yarimai"
REGION="us-central1"
SERVICE_NAME="viral-intelligence-streaming"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Viral Intelligence System - Status Check                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get service URL
echo -e "${YELLOW}Getting service URL...${NC}"
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)' 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    echo -e "${RED}✗ Service not found${NC}"
    echo "Please deploy the service first with: bash deploy-all.sh"
    exit 1
fi

echo -e "${GREEN}✓ Service URL: ${SERVICE_URL}${NC}"
echo ""

# Check 1: Health Endpoint
echo -e "${BLUE}[1/6] Checking Health Endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${SERVICE_URL}/health" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "  Response: $HEALTH_BODY"
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Check 2: Trending Endpoint
echo -e "${BLUE}[2/6] Checking Trending Endpoint...${NC}"
TRENDING_RESPONSE=$(curl -s -w "\n%{http_code}" "${SERVICE_URL}/api/analytics/trending?limit=5" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$TRENDING_RESPONSE" | tail -n1)
TRENDING_BODY=$(echo "$TRENDING_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Trending endpoint working${NC}"
    POST_COUNT=$(echo "$TRENDING_BODY" | grep -o '"post_id"' | wc -l | tr -d ' ')
    echo "  Found $POST_COUNT trending posts"
else
    echo -e "${YELLOW}⚠ Trending endpoint returned HTTP $HTTP_CODE${NC}"
    echo "  This is normal if no data exists yet"
fi
echo ""

# Check 3: Cloud Run Service Status
echo -e "${BLUE}[3/6] Checking Cloud Run Service...${NC}"
SERVICE_STATUS=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.conditions[0].status)' 2>/dev/null || echo "Unknown")

if [ "$SERVICE_STATUS" = "True" ]; then
    echo -e "${GREEN}✓ Cloud Run service is running${NC}"
    
    # Get instance count
    INSTANCES=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.traffic[0].percent)' 2>/dev/null || echo "Unknown")
    echo "  Service is receiving traffic"
else
    echo -e "${RED}✗ Cloud Run service status: $SERVICE_STATUS${NC}"
fi
echo ""

# Check 4: Firestore Collections
echo -e "${BLUE}[4/6] Checking Firestore Collections...${NC}"
echo -e "${YELLOW}  Checking trending_scores collection...${NC}"

# Note: This requires firestore CLI or gcloud firestore commands
# For now, we'll just note what to check
echo -e "${YELLOW}  Manual check required:${NC}"
echo "    1. Go to: https://console.firebase.google.com/project/yarimai/firestore"
echo "    2. Verify these collections exist and have data:"
echo "       - trending_scores"
echo "       - recommendations"
echo "       - posts (with keywords field)"
echo ""

# Check 5: Recent Logs
echo -e "${BLUE}[5/6] Checking Recent Logs...${NC}"
echo -e "${YELLOW}  Fetching last 10 log entries...${NC}"
gcloud run logs read ${SERVICE_NAME} --region ${REGION} --limit 10 2>/dev/null || echo -e "${YELLOW}  Could not fetch logs${NC}"
echo ""

# Check 6: Dashboard
echo -e "${BLUE}[6/6] Checking Dashboard...${NC}"
DASHBOARD_URL="https://yarimai.web.app"
DASHBOARD_RESPONSE=$(curl -s -w "\n%{http_code}" "${DASHBOARD_URL}" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$DASHBOARD_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Dashboard is accessible${NC}"
    echo "  URL: $DASHBOARD_URL"
else
    echo -e "${YELLOW}⚠ Dashboard returned HTTP $HTTP_CODE${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Status Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service Information:${NC}"
echo "  Service URL:  $SERVICE_URL"
echo "  Dashboard:    $DASHBOARD_URL"
echo "  Region:       $REGION"
echo "  Project:      $PROJECT_ID"
echo ""
echo -e "${BLUE}Quick Actions:${NC}"
echo "  View logs:     gcloud run logs tail ${SERVICE_NAME} --region ${REGION}"
echo "  View metrics:  https://console.cloud.google.com/run/detail/${REGION}/${SERVICE_NAME}/metrics"
echo "  Firestore:     https://console.firebase.google.com/project/yarimai/firestore"
echo "  Confluent:     https://confluent.cloud/"
echo ""
echo -e "${BLUE}Test Endpoints:${NC}"
echo "  Health:        curl ${SERVICE_URL}/health"
echo "  Trending:      curl ${SERVICE_URL}/api/analytics/trending?limit=10"
echo "  Send Event:    curl -X POST ${SERVICE_URL}/api/events/interaction -H 'Content-Type: application/json' -d '{\"post_id\":\"test\",\"user_id\":\"user\",\"event_type\":\"like\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}'"
echo ""
echo -e "${GREEN}Status check complete!${NC}"
echo ""
