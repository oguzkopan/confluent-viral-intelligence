#!/bin/bash

# Enhanced Dashboard Deployment Script
set -e

echo "🚀 Deploying Enhanced Viral Intelligence Dashboard..."
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Build the app
echo "🔨 Building dashboard..."
npm run build

# Deploy to Firebase
echo "🌐 Deploying to Firebase Hosting..."
firebase deploy --only hosting --project yarimai

echo ""
echo "✅ Dashboard deployed successfully!"
echo "🔗 URL: https://yarimai.web.app"
echo ""
echo "📊 Test the new features:"
echo "  - Enhanced metrics with 6 key indicators"
echo "  - Top 3 trending content showcase"
echo "  - Popular creators with profiles"
echo "  - Content type distribution"
echo "  - Real-time updates every 30 seconds"
