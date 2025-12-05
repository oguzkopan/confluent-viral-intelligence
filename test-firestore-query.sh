#!/bin/bash

# Test script to check Firestore trending_scores collection

echo "Testing Firestore trending_scores collection..."
echo ""

# Use the Firebase Admin SDK via a simple curl to the API with verbose logging
curl -v "https://viral-intelligence-streaming-799474804867.us-central1.run.app/api/analytics/trending?limit=5" 2>&1

echo ""
echo ""
echo "Checking recent logs for Firestore errors..."
gcloud run services logs read viral-intelligence-streaming --region us-central1 --limit 100 2>&1 | grep -i "firestore\|trending\|error" | tail -20
