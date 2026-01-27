#!/bin/bash
# Unified development script - starts gateway, web, and Swift app together
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    [ -n "$GATEWAY_PID" ] && kill $GATEWAY_PID 2>/dev/null || true
    [ -n "$WEB_PID" ] && kill $WEB_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Check for pnpm
if ! command -v pnpm &> /dev/null; then
    echo -e "${RED}Error: pnpm is required but not installed.${NC}"
    echo "Install with: npm install -g pnpm"
    exit 1
fi

# 1. Start gateway on port 3001
echo -e "${GREEN}Starting gateway on port 3001...${NC}"
PORT=3001 pnpm --filter gateway dev &
GATEWAY_PID=$!

# 2. Start web on port 3000
echo -e "${GREEN}Starting web on port 3000...${NC}"
pnpm --filter web dev &
WEB_PID=$!

# 3. Wait for gateway to be ready
echo -e "${YELLOW}Waiting for gateway to be ready...${NC}"
MAX_WAIT=30
WAIT_COUNT=0
until curl -s http://localhost:3001/v1/health > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo -e "${RED}Gateway failed to start within ${MAX_WAIT}s${NC}"
        exit 1
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done
echo -e "${GREEN}Gateway ready!${NC}"

# 4. Start Swift app pointed at local gateway
echo -e "${GREEN}Starting Vox app...${NC}"
export VOX_GATEWAY_URL=http://localhost:3001
export VOX_WEB_URL=http://localhost:3000
swift run VoxApp
