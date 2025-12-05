#!/bin/bash

# Confluent Cloud Setup Verification Script
# This script verifies that all Kafka topics are created correctly

set -e

echo "=========================================="
echo "Confluent Cloud Setup Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Confluent CLI is installed
if ! command -v confluent &> /dev/null; then
    echo -e "${RED}✗ Confluent CLI is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Confluent CLI is installed${NC}"

# Check if logged in
if ! confluent environment list &> /dev/null; then
    echo -e "${RED}✗ Not logged in to Confluent Cloud${NC}"
    echo "Run: confluent login"
    exit 1
fi

echo -e "${GREEN}✓ Logged in to Confluent Cloud${NC}"
echo ""

# Get current environment and cluster
CURRENT_ENV=$(confluent environment list -o json | jq -r '.[] | select(.is_current == true) | .id' 2>/dev/null || echo "")
CURRENT_CLUSTER=$(confluent kafka cluster list -o json | jq -r '.[] | select(.is_current == true) | .id' 2>/dev/null || echo "")

if [ -z "$CURRENT_ENV" ]; then
    echo -e "${RED}✗ No environment selected${NC}"
    echo "Run: confluent environment use <env-id>"
    exit 1
fi

if [ -z "$CURRENT_CLUSTER" ]; then
    echo -e "${RED}✗ No cluster selected${NC}"
    echo "Run: confluent kafka cluster use <cluster-id>"
    exit 1
fi

echo -e "${YELLOW}Current Environment:${NC} $CURRENT_ENV"
echo -e "${YELLOW}Current Cluster:${NC} $CURRENT_CLUSTER"
echo ""

# Get cluster details
echo "Fetching cluster details..."
CLUSTER_INFO=$(confluent kafka cluster describe "$CURRENT_CLUSTER" -o json 2>/dev/null || echo "{}")
CLUSTER_NAME=$(echo "$CLUSTER_INFO" | jq -r '.name // "unknown"')
BOOTSTRAP_SERVER=$(echo "$CLUSTER_INFO" | jq -r '.endpoint // "unknown"' | sed 's/SASL_SSL:\/\///')

echo -e "${YELLOW}Cluster Name:${NC} $CLUSTER_NAME"
echo -e "${YELLOW}Bootstrap Server:${NC} $BOOTSTRAP_SERVER"
echo ""

# Expected topics
declare -A EXPECTED_TOPICS=(
    ["user-interactions"]="6"
    ["content-metadata"]="3"
    ["view-events"]="6"
    ["remix-events"]="3"
    ["trending-scores"]="3"
    ["recommendations"]="3"
)

echo "Verifying topics..."
echo ""

# Get list of topics
TOPICS=$(confluent kafka topic list -o json 2>/dev/null || echo "[]")

MISSING_TOPICS=()
INCORRECT_PARTITIONS=()
VERIFIED_TOPICS=()

for topic in "${!EXPECTED_TOPICS[@]}"; do
    expected_partitions="${EXPECTED_TOPICS[$topic]}"
    
    # Check if topic exists
    topic_exists=$(echo "$TOPICS" | jq -r --arg topic "$topic" '.[] | select(.name == $topic) | .name' 2>/dev/null || echo "")
    
    if [ -z "$topic_exists" ]; then
        MISSING_TOPICS+=("$topic")
        echo -e "${RED}✗ Topic missing: $topic${NC}"
    else
        # Get topic details
        topic_info=$(confluent kafka topic describe "$topic" -o json 2>/dev/null || echo "{}")
        actual_partitions=$(echo "$topic_info" | jq -r '.partitions_count // 0')
        
        if [ "$actual_partitions" -eq "$expected_partitions" ]; then
            VERIFIED_TOPICS+=("$topic")
            echo -e "${GREEN}✓ $topic${NC} (partitions: $actual_partitions)"
        else
            INCORRECT_PARTITIONS+=("$topic (expected: $expected_partitions, actual: $actual_partitions)")
            echo -e "${YELLOW}⚠ $topic${NC} (expected: $expected_partitions partitions, actual: $actual_partitions)"
        fi
    fi
done

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""

echo -e "${GREEN}Verified Topics: ${#VERIFIED_TOPICS[@]}/6${NC}"
for topic in "${VERIFIED_TOPICS[@]}"; do
    echo "  ✓ $topic"
done

if [ ${#MISSING_TOPICS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing Topics: ${#MISSING_TOPICS[@]}${NC}"
    for topic in "${MISSING_TOPICS[@]}"; do
        echo "  ✗ $topic"
    done
fi

if [ ${#INCORRECT_PARTITIONS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Topics with Incorrect Partitions: ${#INCORRECT_PARTITIONS[@]}${NC}"
    for topic in "${INCORRECT_PARTITIONS[@]}"; do
        echo "  ⚠ $topic"
    done
fi

echo ""

# Check if all topics are verified
if [ ${#VERIFIED_TOPICS[@]} -eq 6 ]; then
    echo -e "${GREEN}=========================================="
    echo "✓ All topics verified successfully!"
    echo "==========================================${NC}"
    echo ""
    echo "Configuration for .env file:"
    echo ""
    echo "CONFLUENT_BOOTSTRAP_SERVERS=$BOOTSTRAP_SERVER"
    echo "CONFLUENT_API_KEY=U5AZXVJ2MO4TNZQO"
    echo "CONFLUENT_API_SECRET=<your-secret>"
    echo ""
    exit 0
else
    echo -e "${RED}=========================================="
    echo "✗ Setup incomplete"
    echo "==========================================${NC}"
    echo ""
    
    if [ ${#MISSING_TOPICS[@]} -gt 0 ]; then
        echo "To create missing topics, run:"
        echo ""
        for topic in "${MISSING_TOPICS[@]}"; do
            partitions="${EXPECTED_TOPICS[$topic]}"
            echo "confluent kafka topic create $topic --partitions $partitions --config retention.ms=604800000 --config compression.type=snappy"
        done
        echo ""
    fi
    
    if [ ${#INCORRECT_PARTITIONS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Note: Partition count cannot be changed after creation.${NC}"
        echo "You may need to delete and recreate topics with incorrect partitions."
        echo ""
    fi
    
    exit 1
fi
