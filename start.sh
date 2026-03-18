#!/bin/bash
# Start LiteLLM proxy with environment loaded from .env
# Usage: ./start.sh [deepseek|zhipu]
# Default: deepseek

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="${1:-deepseek}"
CONFIG_FILE="config.${CONFIG}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found"
  exit 1
fi

if [ ! -f ".env" ]; then
  echo "Error: .env file not found in $SCRIPT_DIR"
  exit 1
fi

# Load env vars
set -a
source .env
set +a

echo "Starting LiteLLM with $CONFIG_FILE"
echo "DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY:0:10}..."

exec litellm --config "$CONFIG_FILE"
