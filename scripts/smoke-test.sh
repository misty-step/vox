#!/bin/bash
# Smoke test script for Vox gateway
# Run this after deploying to verify endpoints work

set -e

# Configuration
GATEWAY_URL="${GATEWAY_URL:-http://localhost:3000}"
AUTH_TOKEN="${VOX_TEST_TOKEN:-test-token}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Vox Gateway Smoke Tests"
echo "=========================="
echo "Target: $GATEWAY_URL"
echo ""

# Track failures
FAILED=0

test_endpoint() {
  local name=$1
  local method=$2
  local path=$3
  local expected_status=$4
  local data=$5

  printf "%-40s" "Testing $name..."

  if [ "$method" = "GET" ]; then
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $AUTH_TOKEN" "$GATEWAY_URL$path")
  else
    response=$(curl -s -w "\n%{http_code}" -X "$method" \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "$GATEWAY_URL$path")
  fi

  status=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [ "$status" = "$expected_status" ]; then
    echo -e "${GREEN}✓ $status${NC}"
    return 0
  else
    echo -e "${RED}✗ Expected $expected_status, got $status${NC}"
    echo "  Response: $body"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

# Health check (no auth required)
printf "%-40s" "Testing Health (no auth)..."
response=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/v1/health")
status=$(echo "$response" | tail -n1)
if [ "$status" = "200" ]; then
  echo -e "${GREEN}✓ 200${NC}"
else
  echo -e "${RED}✗ Expected 200, got $status${NC}"
  FAILED=$((FAILED + 1))
fi

# Config endpoint
test_endpoint "Config" "GET" "/v1/config" "200"

# Auth required endpoints - without token should fail
printf "%-40s" "Testing Entitlements (no auth)..."
response=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/v1/entitlements")
status=$(echo "$response" | tail -n1)
if [ "$status" = "401" ]; then
  echo -e "${GREEN}✓ 401 (correctly rejected)${NC}"
else
  echo -e "${YELLOW}⚠ Expected 401, got $status${NC}"
fi

# Entitlements with auth
test_endpoint "Entitlements (authed)" "GET" "/v1/entitlements" "200"

# STT Token
test_endpoint "STT Token" "POST" "/v1/stt/token" "200" "{}"

# Rewrite endpoint
test_endpoint "Rewrite (light)" "POST" "/v1/rewrite" "200" \
  '{"sessionId":"smoke-test","locale":"en","transcript":{"text":"this is a test"},"context":"","processingLevel":"light"}'

echo ""
echo "=========================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All smoke tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILED test(s) failed${NC}"
  exit 1
fi
