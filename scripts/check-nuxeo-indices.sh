#!/usr/bin/env bash
# =============================================================================
# Checks that the expected OpenSearch indices exist and are healthy.
# With the vector feature enabled you should see BOTH "nuxeo" and "nuxeo-vector".
#
# Usage:
#   ./scripts/check-nuxeo-indices.sh                 # http://localhost:9200
#   ./scripts/check-nuxeo-indices.sh http://host:9200
# =============================================================================

ES_URL="${1:-http://localhost:9200}"

EXPECTED_INDICES="nuxeo nuxeo-vector"

RESULTS="$(curl -s "$ES_URL/_cat/indices?h=health,index")"

if [ $? -ne 0 ] || [ -z "$RESULTS" ]; then
  echo "ERROR: Cannot connect to OpenSearch at $ES_URL"
  exit 2
fi

EXIT_CODE=0

for INDEX in $EXPECTED_INDICES; do
  LINE="$(echo "$RESULTS" | awk -v idx="$INDEX" '$2 == idx { print $0 }')"

  if [ -z "$LINE" ]; then
    echo "MISSING: $INDEX"
    EXIT_CODE=1
    continue
  fi

  HEALTH="$(echo "$LINE" | awk '{ print $1 }')"

  if [ "$HEALTH" = "green" ] || [ "$HEALTH" = "yellow" ]; then
    echo "OK: $INDEX is $HEALTH"
  else
    echo "BAD: $INDEX is $HEALTH"
    EXIT_CODE=1
  fi
done

exit "$EXIT_CODE"
