#!/usr/bin/env bash
# =============================================================================
# One-time (fire-and-forget) reindex of the VECTOR index.
#
# After Nuxeo starts with the vector client + a valid model.id, the vector
# index ("nuxeo-vector", reached via index=vector) is empty and Nuxeo logs
# errors that it does not exist until it is built once. This triggers the bulk
# reindex that chunks + embeds existing content into the vector index. The main
# repository index is NOT touched.
#
# It returns immediately (the bulk action runs asynchronously server-side).
# Watch progress in the Nuxeo logs, or with:  make check-indices
#
# Re-run it only after wiping the OpenSearch volume, or use the Admin Console
# (Admin > Elasticsearch/OpenSearch > Reindex) to reindex the vector index.
#
# Usage:
#   ./scripts/reindex-vector.sh
#   NUXEO_URL=http://localhost:8080/nuxeo NUXEO_USER=Administrator \
#     NUXEO_PWD=Administrator ./scripts/reindex-vector.sh
# =============================================================================
set -euo pipefail

NUXEO_URL="${NUXEO_URL:-http://localhost:8080/nuxeo}"
NUXEO_USER="${NUXEO_USER:-Administrator}"
NUXEO_PWD="${NUXEO_PWD:-Administrator}"
QUERY="${QUERY:-SELECT * FROM Document}"

echo "==> Triggering one-time vector reindex on ${NUXEO_URL} (index=vector)..."
echo "    query: ${QUERY}"

curl -u "${NUXEO_USER}:${NUXEO_PWD}" -X POST \
  "${NUXEO_URL}/api/v1/search/bulk/reindex?index=vector" \
  -H 'Content-Type: application/json' \
  -d "{\"query\":\"${QUERY}\"}"

echo
echo "==> Submitted. The bulk action runs asynchronously (fire-and-forget)."
echo "    Watch the Nuxeo logs and run: make check-indices"
