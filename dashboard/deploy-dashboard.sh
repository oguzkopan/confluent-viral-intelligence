#!/bin/bash

# Viral Intelligence Dashboard Deployment Script
# Rebuilds with production environment variables and deploys to Firebase Hosting

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Viral Intelligence Dashboard - Deployment                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cloud Run service URL
API_URL="https://viral-intelligence-streaming-76fj3utobq-uc.a.run.app"
WS_URL="wss://viral-intelligence-streaming-76fj3utobq-uc.a.run.app/ws"

echo "═══════════════════════════════════════════════════════════"
echo "Configuration"
echo "═══════════════════════════════════════════════════════════"
echo "API URL: $API_URL"
echo "WebSocket URL: $WS_URL"
echo ""

# Navigate to dashboard directory
cd "$(dirname "$0")"

echo "═══════════════════════════════════════════════════════════"
echo "Installing Dependencies"
echo "═══════════════════════════════════════════════════════════"
npm install

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Building Dashboard with Production Environment Variables"
echo "═══════════════════════════════════════════════════════════"
echo "Setting REACT_APP_API_URL=$API_URL"
echo "Setting REACT_APP_WS_URL=$WS_URL"
echo ""

# Build with explicit environment variables
REACT_APP_API_URL="$API_URL" REACT_APP_WS_URL="$WS_URL" npm run build

# Verify the build contains the correct URLs
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Verifying Build Configuration"
echo "═══════════════════════════════════════════════════════════"

if grep -q "localhost:8080" build/static/js/*.js 2>/dev/null; then
    echo -e "${RED}✗ ERROR: Build still contains localhost:8080${NC}"
    echo "Environment variables were not properly injected during build."
    exit 1
fi

if grep -q "$API_URL" build/static/js/*.js 2>/dev/null; then
    echo -e "${GREEN}✓ Build contains correct API URL${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not verify API URL in build${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Deploying to Firebase Hosting"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Deploying to:"
echo "  • viral-intelligence-dashboard.web.app"
echo "  • yarimai.web.app"
echo ""

# Deploy to both hosting targets
firebase deploy --only hosting

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Dashboard URLs:"
echo "  • https://viral-intelligence-dashboard.web.app"
echo "  • https://viral-intelligence-dashboard.firebaseapp.com"
echo "  • https://yarimai.web.app"
echo ""
echo "To verify the deployment:"
echo "  1. Open the URLs above in your browser"
echo "  2. Check browser console for WebSocket connection"
echo "  3. Verify trending posts are loading"
echo ""
