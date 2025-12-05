#!/bin/bash

# Simple script to update Confluent Cloud credentials in Cloud Run
# This makes it easy to configure your service once you have the values

echo "================================================"
echo "Update Confluent Cloud Credentials"
echo "================================================"
echo ""
echo "This script will help you update your Cloud Run service"
echo "with your Confluent Cloud credentials."
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI is not installed"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo "First, let's find your credentials in Confluent Cloud:"
echo ""
echo "1. Go to: https://confluent.cloud"
echo "2. Click on your cluster"
echo "3. Go to 'Cluster settings' to find Bootstrap Server"
echo "4. Go to 'API keys' to find or create your API key"
echo ""
echo "================================================"
echo ""

# Prompt for Bootstrap Server
echo "Enter your Bootstrap Server URL:"
echo "(Example: pkc-xxxxx.us-central1.gcp.confluent.cloud:9092)"
read -p "> " BOOTSTRAP_SERVER

if [ -z "$BOOTSTRAP_SERVER" ]; then
    echo "❌ Error: Bootstrap Server cannot be empty"
    exit 1
fi

echo ""

# Prompt for API Secret
echo "Enter your API Secret:"
echo "(This is the password for your API key)"
read -sp "> " API_SECRET
echo ""

if [ -z "$API_SECRET" ]; then
    echo "❌ Error: API Secret cannot be empty"
    exit 1
fi

echo ""
echo "================================================"
echo "Configuration Summary:"
echo "================================================"
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "API Key: U5AZXVJ2MO4TNZQO"
echo "API Secret: ********** (hidden)"
echo ""
read -p "Does this look correct? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled. Please run the script again."
    exit 1
fi

echo ""
echo "Updating Cloud Run service..."
echo ""

# Update the Cloud Run service
gcloud run services update viral-intelligence-streaming \
  --region us-central1 \
  --project yarimai \
  --update-env-vars "CONFLUENT_BOOTSTRAP_SERVERS=$BOOTSTRAP_SERVER,CONFLUENT_API_SECRET=$API_SECRET"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ Success! Credentials updated"
    echo "================================================"
    echo ""
    echo "Your service is now configured with Confluent Cloud credentials."
    echo ""
    echo "Next steps:"
    echo "1. Check the logs: gcloud run logs tail viral-intelligence-streaming --region us-central1"
    echo "2. Test the service: curl https://viral-intelligence-streaming-799474804867.us-central1.run.app/health"
    echo ""
else
    echo ""
    echo "================================================"
    echo "❌ Error updating service"
    echo "================================================"
    echo ""
    echo "Please check:"
    echo "1. You're logged in to gcloud: gcloud auth login"
    echo "2. You have access to project 'yarimai'"
    echo "3. The service name is correct"
    echo ""
fi
