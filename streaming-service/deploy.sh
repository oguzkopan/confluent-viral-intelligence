#!/bin/bash

# Deployment script for Viral Intelligence Streaming Service to Cloud Run
set -e

# Configuration
PROJECT_ID="yarimai"
SERVICE_NAME="viral-intelligence-streaming"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment of ${SERVICE_NAME}...${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting GCP project to ${PROJECT_ID}...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
gcloud builds submit --tag ${IMAGE_NAME}

# Check if .env file exists for environment variables
if [ ! -f .env ]; then
    echo -e "${RED}Warning: .env file not found. Please ensure environment variables are set.${NC}"
    echo -e "${YELLOW}You can copy .env.example to .env and fill in the values.${NC}"
fi

# Read environment variables from .env file
if [ -f .env ]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)
fi

# Deploy to Cloud Run
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 2 \
  --timeout 300s \
  --min-instances 1 \
  --max-instances 10 \
  --set-env-vars "CONFLUENT_BOOTSTRAP_SERVERS=${CONFLUENT_BOOTSTRAP_SERVERS:-pkc-placeholder},CONFLUENT_API_KEY=${CONFLUENT_API_KEY:-U5AZXVJ2MO4TNZQO},CONFLUENT_API_SECRET=${CONFLUENT_API_SECRET:-placeholder},GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT:-yarimai},FIRESTORE_PROJECT_ID=${FIRESTORE_PROJECT_ID:-yarimai},VERTEX_AI_LOCATION=${VERTEX_AI_LOCATION:-us-central1},ENVIRONMENT=production,ALLOWED_ORIGINS=*" \
  --service-account "${SERVICE_ACCOUNT:-799474804867-compute@developer.gserviceaccount.com}"

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')

echo -e "${GREEN}Deployment successful!${NC}"
echo -e "${GREEN}Service URL: ${SERVICE_URL}${NC}"
echo -e "${YELLOW}Testing health endpoint...${NC}"

# Test the health endpoint
sleep 5
if curl -f "${SERVICE_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}Health check passed!${NC}"
else
    echo -e "${RED}Warning: Health check failed. Please check the logs.${NC}"
    echo -e "${YELLOW}View logs with: gcloud run logs read ${SERVICE_NAME} --region ${REGION}${NC}"
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update CORS settings if needed"
echo -e "2. Test the API endpoints"
echo -e "3. Monitor logs: gcloud run logs tail ${SERVICE_NAME} --region ${REGION}"
echo -e "4. Update dashboard with service URL: ${SERVICE_URL}"
