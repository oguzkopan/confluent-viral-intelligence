#!/bin/bash

# Test script for dashboard deployment
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DASHBOARD_URL="https://yarimai.web.app"

echo -e "${YELLOW}Testing Dashboard Deployment...${NC}"
echo ""

# Test 1: Check if dashboard is accessible
echo -e "${YELLOW}Test 1: Checking dashboard accessibility...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_URL")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Dashboard is accessible (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Dashboard returned HTTP $HTTP_CODE${NC}"
    exit 1
fi

# Test 2: Check if HTML content is served
echo -e "${YELLOW}Test 2: Checking HTML content...${NC}"
CONTENT=$(curl -s "$DASHBOARD_URL")

if echo "$CONTENT" | grep -qi "<!doctype html>"; then
    echo -e "${GREEN}✓ HTML content is being served${NC}"
else
    echo -e "${RED}✗ No HTML content found${NC}"
    exit 1
fi

# Test 3: Check for React app root
if echo "$CONTENT" | grep -q "root"; then
    echo -e "${GREEN}✓ React app root element found${NC}"
else
    echo -e "${RED}✗ React app root element not found${NC}"
    exit 1
fi

# Test 4: Check response headers
echo -e "${YELLOW}Test 4: Checking security headers...${NC}"
HEADERS=$(curl -s -I "$DASHBOARD_URL")

if echo "$HEADERS" | grep -q "X-Frame-Options"; then
    echo -e "${GREEN}✓ Security headers present${NC}"
else
    echo -e "${YELLOW}⚠ Some security headers may be missing${NC}"
fi

echo ""
echo -e "${GREEN}Dashboard deployment tests completed!${NC}"
echo -e "${YELLOW}Dashboard URL: $DASHBOARD_URL${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Open $DASHBOARD_URL in a browser"
echo "2. Check browser console for any errors"
echo "3. Verify WebSocket connection status"
echo "4. Test with streaming service once deployed"
