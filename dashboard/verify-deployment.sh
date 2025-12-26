#!/bin/bash

# Verify Dashboard Deployment Script
# Checks if the deployed dashboard is accessible and configured correctly

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Verifying Dashboard Deployment                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# URLs to check
URLS=(
    "https://viral-intelligence-dashboard.web.app"
    "https://viral-intelligence-dashboard.firebaseapp.com"
    "https://yarimai.web.app"
)

echo "Checking dashboard accessibility..."
echo ""

for url in "${URLS[@]}"; do
    echo -n "Testing $url ... "
    
    # Check if URL is accessible
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$status_code" -eq 200 ]; then
        echo -e "${GREEN}✓ OK (HTTP $status_code)${NC}"
        
        # Check if it contains localhost (which would be bad)
        content=$(curl -s "$url")
        if echo "$content" | grep -q "localhost:8080"; then
            echo -e "  ${RED}✗ WARNING: Still contains localhost:8080${NC}"
        else
            echo -e "  ${GREEN}✓ No localhost references found${NC}"
        fi
    else
        echo -e "${RED}✗ FAILED (HTTP $status_code)${NC}"
    fi
    echo ""
done

echo "═══════════════════════════════════════════════════════════"
echo "Checking Cloud Run Service..."
echo "═══════════════════════════════════════════════════════════"

API_URL="https://viral-intelligence-streaming-76fj3utobq-uc.a.run.app"

echo -n "Testing $API_URL/health ... "
health_status=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")

if [ "$health_status" -eq 200 ]; then
    echo -e "${GREEN}✓ OK (HTTP $health_status)${NC}"
else
    echo -e "${RED}✗ FAILED (HTTP $health_status)${NC}"
    echo -e "${YELLOW}Note: Service might be cold-starting. Try again in a few seconds.${NC}"
fi

echo ""
echo -n "Testing $API_URL/api/analytics/trending ... "
trending_status=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/analytics/trending?limit=5")

if [ "$trending_status" -eq 200 ]; then
    echo -e "${GREEN}✓ OK (HTTP $trending_status)${NC}"
else
    echo -e "${RED}✗ FAILED (HTTP $trending_status)${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Verification Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Open the dashboard URLs in your browser"
echo "  2. Open browser DevTools (F12) and check Console tab"
echo "  3. Look for 'WebSocket connected' message"
echo "  4. Verify trending posts are displayed"
echo ""
