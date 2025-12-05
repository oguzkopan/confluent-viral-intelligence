#!/bin/bash

# Simple deployment verification script
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Viral Intelligence Deployment Verification"
echo "=========================================="
echo ""

# Check API Health
echo -n "Checking API health... "
if curl -sf "https://viral-intelligence-streaming-799474804867.us-central1.run.app/health" > /dev/null; then
    echo -e "${GREEN}✓ API is healthy${NC}"
else
    echo -e "${RED}✗ API health check failed${NC}"
    exit 1
fi

# Check API returns data
echo -n "Checking API returns trending data... "
RESPONSE=$(curl -s "https://viral-intelligence-streaming-799474804867.us-central1.run.app/api/analytics/trending?limit=5")
COUNT=$(echo $RESPONSE | jq -r '.count // 0')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ API returning $COUNT trending posts${NC}"
else
    echo -e "${YELLOW}⚠ API returning 0 posts (may need more events)${NC}"
fi

# Check CORS
echo -n "Checking CORS configuration... "
CORS=$(curl -s -H "Origin: https://viral-intelligence-dashboard.firebaseapp.com" \
    -I "https://viral-intelligence-streaming-799474804867.us-central1.run.app/api/analytics/trending?limit=1" 2>&1 | \
    grep -i "access-control-allow-origin" | grep -c "\*")
if [ "$CORS" -gt 0 ]; then
    echo -e "${GREEN}✓ CORS configured correctly${NC}"
else
    echo -e "${RED}✗ CORS not configured${NC}"
fi

# Check Dashboard
echo -n "Checking dashboard deployment... "
if curl -sf "https://viral-intelligence-dashboard.web.app" > /dev/null; then
    echo -e "${GREEN}✓ Dashboard is accessible${NC}"
else
    echo -e "${RED}✗ Dashboard not accessible${NC}"
fi

# Check Cloud Run service
echo -n "Checking Cloud Run service status... "
SERVICE_STATUS=$(gcloud run services describe viral-intelligence-streaming \
    --region us-central1 \
    --format='value(status.conditions[0].status)' 2>/dev/null || echo "Unknown")
if [ "$SERVICE_STATUS" = "True" ]; then
    echo -e "${GREEN}✓ Cloud Run service is running${NC}"
else
    echo -e "${YELLOW}⚠ Cloud Run service status: $SERVICE_STATUS${NC}"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo -e "${GREEN}✓ Streaming Service:${NC} https://viral-intelligence-streaming-799474804867.us-central1.run.app"
echo -e "${GREEN}✓ Dashboard:${NC} https://viral-intelligence-dashboard.web.app"
echo -e "${GREEN}✓ Alternative Dashboard:${NC} https://viral-intelligence-dashboard.firebaseapp.com"
echo ""
echo "To view logs:"
echo "  gcloud run logs tail viral-intelligence-streaming --region us-central1"
echo ""
echo "To redeploy:"
echo "  cd streaming-service && ./deploy.sh"
echo ""
