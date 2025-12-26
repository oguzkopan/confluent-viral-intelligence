#!/bin/bash

# Deploy Confluent Dashboard to yarimai.web.app
# This deploys the viral intelligence dashboard to the yarimai.web.app domain

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deploy Confluent Dashboard to yarimai.web.app           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will deploy the viral intelligence dashboard to:${NC}"
echo "  - https://yarimai.web.app"
echo "  - https://yarimai.firebaseapp.com"
echo ""
echo -e "${YELLOW}Note:${NC} Your main app is on yarimai.com (App Hosting)"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}✗ package.json not found${NC}"
    echo "Please run this script from the dashboard directory:"
    echo "  cd hackathon-confluent-viral-intelligence/dashboard"
    echo "  bash deploy-to-yarimai.sh"
    exit 1
fi

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Build the dashboard
echo -e "${YELLOW}Building dashboard...${NC}"
npm run build

if [ ! -d "build" ]; then
    echo -e "${RED}✗ Build failed - build directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Deploy to yarimai.web.app
echo -e "${YELLOW}Deploying to yarimai.web.app...${NC}"
firebase deploy --only hosting:yarimai-dashboard --project yarimai

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Dashboard URLs${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Viral Intelligence Dashboard:${NC}"
echo "  - https://yarimai.web.app"
echo "  - https://yarimai.firebaseapp.com"
echo "  - https://viral-intelligence-dashboard.web.app"
echo "  - https://viral-intelligence-dashboard.firebaseapp.com"
echo ""
echo -e "${GREEN}Main YarimAI App:${NC}"
echo "  - https://yarimai.com (App Hosting)"
echo ""

echo -e "${YELLOW}Note:${NC} It may take a few minutes for changes to propagate."
echo "Clear your browser cache if you still see old content."
echo ""

echo -e "${GREEN}Done! 🎉${NC}"
