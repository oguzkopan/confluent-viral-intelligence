#!/bin/bash

# Confluent Cloud Infrastructure Setup Script
# This script helps set up the Kafka topics and Flink compute pool for the Viral Intelligence System

set -e

echo "=========================================="
echo "Confluent Cloud Infrastructure Setup"
echo "=========================================="
echo ""

# Configuration
CONFLUENT_API_KEY="U5AZXVJ2MO4TNZQO"
CLUSTER_NAME="viral-intelligence-cluster"
ENVIRONMENT_NAME="yarimai-production"
REGION="us-central1"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Prerequisites:${NC}"
echo "1. Confluent Cloud account created"
echo "2. Confluent CLI installed (https://docs.confluent.io/confluent-cli/current/install.html)"
echo "3. API Key: $CONFLUENT_API_KEY"
echo "4. API Secret available"
echo ""

# Check if Confluent CLI is installed
if ! command -v confluent &> /dev/null; then
    echo -e "${RED}Error: Confluent CLI is not installed${NC}"
    echo "Install it from: https://docs.confluent.io/confluent-cli/current/install.html"
    exit 1
fi

echo -e "${GREEN}✓ Confluent CLI is installed${NC}"
echo ""

# Login prompt
echo -e "${YELLOW}Step 1: Login to Confluent Cloud${NC}"
echo "Run: confluent login"
echo "Press Enter when logged in..."
read -r

# List environments
echo ""
echo -e "${YELLOW}Step 2: Select or Create Environment${NC}"
echo "Listing available environments..."
confluent environment list

echo ""
echo "Enter environment ID (or press Enter to create new):"
read -r ENV_ID

if [ -z "$ENV_ID" ]; then
    echo "Creating new environment: $ENVIRONMENT_NAME"
    ENV_ID=$(confluent environment create "$ENVIRONMENT_NAME" -o json | jq -r '.id')
    echo -e "${GREEN}✓ Created environment: $ENV_ID${NC}"
fi

confluent environment use "$ENV_ID"
echo -e "${GREEN}✓ Using environment: $ENV_ID${NC}"
echo ""

# Create or select cluster
echo -e "${YELLOW}Step 3: Create or Select Kafka Cluster${NC}"
echo "Listing available clusters..."
confluent kafka cluster list

echo ""
echo "Enter cluster ID (or press Enter to create new):"
read -r CLUSTER_ID

if [ -z "$CLUSTER_ID" ]; then
    echo "Creating new Basic cluster: $CLUSTER_NAME in $REGION"
    echo "This will create a Basic cluster (suitable for development/testing)"
    echo "For production, consider Standard or Dedicated clusters"
    echo ""
    echo "Creating cluster..."
    CLUSTER_ID=$(confluent kafka cluster create "$CLUSTER_NAME" \
        --cloud gcp \
        --region "$REGION" \
        --type basic \
        -o json | jq -r '.id')
    
    echo -e "${GREEN}✓ Created cluster: $CLUSTER_ID${NC}"
    echo "Waiting for cluster to be ready (this may take a few minutes)..."
    sleep 30
fi

confluent kafka cluster use "$CLUSTER_ID"
echo -e "${GREEN}✓ Using cluster: $CLUSTER_ID${NC}"

# Get bootstrap server
echo ""
echo -e "${YELLOW}Step 4: Get Bootstrap Server URL${NC}"
BOOTSTRAP_SERVER=$(confluent kafka cluster describe "$CLUSTER_ID" -o json | jq -r '.endpoint' | sed 's/SASL_SSL:\/\///')
echo -e "${GREEN}✓ Bootstrap Server: $BOOTSTRAP_SERVER${NC}"
echo ""

# Create API Key if needed
echo -e "${YELLOW}Step 5: API Key Configuration${NC}"
echo "Using API Key: $CONFLUENT_API_KEY"
echo ""
echo "If you need to create a new API key, run:"
echo "  confluent api-key create --resource $CLUSTER_ID"
echo ""
echo "Do you have the API Secret for key $CONFLUENT_API_KEY? (y/n)"
read -r HAS_SECRET

if [ "$HAS_SECRET" != "y" ]; then
    echo -e "${RED}Please obtain the API Secret and save it securely${NC}"
    echo "You'll need it for the .env file"
    exit 1
fi

echo "Enter API Secret (it will be hidden):"
read -rs API_SECRET
echo ""

# Store API key for this session
confluent api-key use "$CONFLUENT_API_KEY" --resource "$CLUSTER_ID"
echo -e "${GREEN}✓ API Key configured${NC}"
echo ""

# Create Kafka Topics
echo -e "${YELLOW}Step 6: Create Kafka Topics${NC}"
echo "Creating topics with specified partitions and retention..."
echo ""

# Topic configurations
declare -A TOPICS=(
    ["user-interactions"]="6:7"
    ["content-metadata"]="3:7"
    ["view-events"]="6:7"
    ["remix-events"]="3:7"
    ["trending-scores"]="3:7"
    ["recommendations"]="3:7"
)

for topic in "${!TOPICS[@]}"; do
    IFS=':' read -r partitions retention <<< "${TOPICS[$topic]}"
    retention_ms=$((retention * 24 * 60 * 60 * 1000))
    
    echo "Creating topic: $topic (partitions: $partitions, retention: ${retention}d)"
    
    if confluent kafka topic create "$topic" \
        --partitions "$partitions" \
        --config retention.ms="$retention_ms" \
        --config compression.type=snappy 2>/dev/null; then
        echo -e "${GREEN}✓ Created topic: $topic${NC}"
    else
        echo -e "${YELLOW}⚠ Topic $topic may already exist${NC}"
    fi
done

echo ""
echo -e "${GREEN}✓ All topics created/verified${NC}"
echo ""

# List topics
echo "Verifying topics..."
confluent kafka topic list
echo ""

# Create Flink Compute Pool
echo -e "${YELLOW}Step 7: Create Flink Compute Pool${NC}"
echo "Note: Flink requires a Standard or Dedicated cluster"
echo "If you're using a Basic cluster, you'll need to upgrade or create a new cluster"
echo ""
echo "Do you want to create a Flink compute pool? (y/n)"
read -r CREATE_FLINK

if [ "$CREATE_FLINK" = "y" ]; then
    echo "Creating Flink compute pool..."
    echo "Pool name: viral-intelligence-flink"
    echo "Region: $REGION"
    echo "Max CFUs: 5"
    
    FLINK_POOL_ID=$(confluent flink compute-pool create viral-intelligence-flink \
        --cloud gcp \
        --region "$REGION" \
        --max-cfu 5 \
        -o json 2>/dev/null | jq -r '.id' || echo "")
    
    if [ -n "$FLINK_POOL_ID" ]; then
        echo -e "${GREEN}✓ Created Flink compute pool: $FLINK_POOL_ID${NC}"
    else
        echo -e "${YELLOW}⚠ Could not create Flink pool. You may need to upgrade your cluster.${NC}"
        echo "You can create it manually in the Confluent Cloud UI:"
        echo "1. Go to your cluster in Confluent Cloud"
        echo "2. Navigate to Flink SQL"
        echo "3. Create a compute pool with 5 CFUs"
    fi
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "----------------------"
echo "Environment ID: $ENV_ID"
echo "Cluster ID: $CLUSTER_ID"
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "API Key: $CONFLUENT_API_KEY"
echo ""
echo "Topics Created:"
for topic in "${!TOPICS[@]}"; do
    echo "  - $topic"
done
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Save the following to your .env file:"
echo ""
echo "   CONFLUENT_BOOTSTRAP_SERVERS=$BOOTSTRAP_SERVER"
echo "   CONFLUENT_API_KEY=$CONFLUENT_API_KEY"
echo "   CONFLUENT_API_SECRET=<your-secret>"
echo ""
echo "2. Update flink-sql/aggregations.sql with:"
echo "   Replace YOUR_BOOTSTRAP_SERVER with: $BOOTSTRAP_SERVER"
echo ""
echo "3. Run the Flink SQL statements in Confluent Cloud UI"
echo "4. Deploy the streaming service"
echo ""
echo -e "${GREEN}Setup script completed successfully!${NC}"
