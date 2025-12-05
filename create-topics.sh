#!/bin/bash

# Script to create Kafka topics in Confluent Cloud
# This creates all the topics needed for the viral intelligence system

echo "================================================"
echo "Create Kafka Topics in Confluent Cloud"
echo "================================================"
echo ""

# Your cluster details
CLUSTER_ID="lkc-q3dy17"
BOOTSTRAP_SERVER="pkc-619z3.us-east1.gcp.confluent.cloud:9092"

echo "Cluster ID: $CLUSTER_ID"
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo ""

# Check if confluent CLI is installed
if ! command -v confluent &> /dev/null; then
    echo "⚠️  Confluent CLI is not installed"
    echo ""
    echo "You have 2 options:"
    echo ""
    echo "Option 1: Install Confluent CLI (Recommended)"
    echo "  brew install confluentinc/tap/cli"
    echo "  Then run this script again"
    echo ""
    echo "Option 2: Create topics manually in Confluent Cloud UI"
    echo "  1. Go to: https://confluent.cloud"
    echo "  2. Navigate to your cluster: $CLUSTER_ID"
    echo "  3. Click 'Topics' in the left sidebar"
    echo "  4. Create these 6 topics:"
    echo ""
    echo "     Topic Name           | Partitions"
    echo "     ---------------------|------------"
    echo "     user-interactions    | 6"
    echo "     content-metadata     | 3"
    echo "     view-events          | 6"
    echo "     remix-events         | 3"
    echo "     trending-scores      | 3"
    echo "     recommendations      | 3"
    echo ""
    exit 1
fi

echo "✅ Confluent CLI is installed"
echo ""

# Check if logged in
if ! confluent environment list &> /dev/null; then
    echo "⚠️  Not logged in to Confluent Cloud"
    echo "Please run: confluent login"
    echo "Then run this script again"
    exit 1
fi

echo "✅ Logged in to Confluent Cloud"
echo ""

# Use the cluster
echo "Setting cluster context..."
confluent kafka cluster use $CLUSTER_ID

echo ""
echo "Creating topics..."
echo ""

# Create topics
topics=(
    "user-interactions:6"
    "content-metadata:3"
    "view-events:6"
    "remix-events:3"
    "trending-scores:3"
    "recommendations:3"
)

for topic_config in "${topics[@]}"; do
    IFS=':' read -r topic partitions <<< "$topic_config"
    
    echo "Creating topic: $topic (partitions: $partitions)"
    
    confluent kafka topic create "$topic" \
        --partitions "$partitions" \
        --config retention.ms=604800000 \
        --config compression.type=snappy \
        2>&1 | grep -v "Error: Topic" || echo "  ✅ Topic created or already exists"
done

echo ""
echo "================================================"
echo "Verifying topics..."
echo "================================================"
echo ""

confluent kafka topic list

echo ""
echo "================================================"
echo "✅ Done!"
echo "================================================"
echo ""
echo "Your topics are ready. The service should now connect successfully."
echo ""
echo "Verify by checking the logs:"
echo "  gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=viral-intelligence-streaming\" --limit 10 --project yarimai --freshness=2m"
echo ""
