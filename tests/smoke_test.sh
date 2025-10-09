#!/bin/bash

# Usage: ./smoke_test.sh <healthcheck_url>
HEALTHCHECK_URL=$1

if [ -z "$HEALTHCHECK_URL" ]; then
  echo "Usage: $0 <healthcheck_url>"
  exit 1
fi

echo "Running health check against $HEALTHCHECK_URL ..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$HEALTHCHECK_URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Health check PASSED (HTTP $HTTP_STATUS)"
  exit 0
else
  echo "Health check FAILED (HTTP $HTTP_STATUS)"
  echo "Response body:"
  curl -s "$HEALTHCHECK_URL"
  exit 1
fi
