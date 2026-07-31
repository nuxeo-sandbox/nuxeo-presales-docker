#!/usr/bin/env bash
# =============================================================================
# Registers and deploys the embedding model on the OpenSearch 3.7 cluster,
# creates the `nuxeo-embedding` ingest pipeline, then prints the model_id you
# must paste into conf/vector-search.conf
# (nuxeo.search.client.vector.opensearch2.model.id).
#
# Idempotent: safe to re-run. It looks the model up by name and skips
# registration if it already exists, and only deploys it if not already
# DEPLOYED.
#
# Run this AFTER `docker compose up -d opensearch` is healthy and BEFORE
# (re)starting Nuxeo. OpenSearch is reached on the host at localhost:9200
# (published on loopback by docker-compose.yml).
#
# Requirements on the host: bash, curl, python3 (present by default on recent
# macOS with Xcode Command Line Tools). python3 parses the JSON responses.
#
# Usage:
#   ./scripts/register-embedding-model.sh
#   OS_URL=http://localhost:9200 ./scripts/register-embedding-model.sh
# =============================================================================
set -euo pipefail

# --- Read the few keys we need from .env WITHOUT shell-sourcing it -----------
# The .env is a Docker Compose env_file: values may contain spaces (e.g.
# NUXEO_PACKAGES=a b c). Sourcing it with `.` would make bash try to execute
# those tokens as commands. So we extract only the keys we care about.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
get_env() {
  # get_env KEY -> prints the raw value of KEY from .env (last wins), or nothing.
  [ -f "${ENV_FILE}" ] || return 0
  { grep -E "^${1}=" "${ENV_FILE}" || true; } | tail -n1 | cut -d= -f2-
}
OS_PORT="${OS_PORT:-$(get_env OS_PORT)}"
EMBEDDING_MODEL_NAME="${EMBEDDING_MODEL_NAME:-$(get_env EMBEDDING_MODEL_NAME)}"
EMBEDDING_MODEL_VERSION="${EMBEDDING_MODEL_VERSION:-$(get_env EMBEDDING_MODEL_VERSION)}"
EMBEDDING_MODEL_FORMAT="${EMBEDDING_MODEL_FORMAT:-$(get_env EMBEDDING_MODEL_FORMAT)}"

OS_URL="${OS_URL:-http://localhost:${OS_PORT:-9200}}"
MODEL_NAME="${EMBEDDING_MODEL_NAME:-huggingface/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2}"
MODEL_VERSION="${EMBEDDING_MODEL_VERSION:-1.0.1}"
MODEL_FORMAT="${EMBEDDING_MODEL_FORMAT:-TORCH_SCRIPT}"
PIPELINE="${PIPELINE:-nuxeo-embedding}"

# Parameterizable ML Commons dynamic cluster settings.
ONLY_ON_ML="${ONLY_ON_ML:-false}"
NATIVE_MEM="${NATIVE_MEM:-100}"

echo "==> OpenSearch        : ${OS_URL}"
echo "==> Embedding model   : ${MODEL_NAME} (v${MODEL_VERSION}, ${MODEL_FORMAT})"
echo "==> Ingest pipeline   : ${PIPELINE}"
echo

jget() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)" 2>/dev/null; }

# --- 0. Wait for the cluster ------------------------------------------------
echo "==> Waiting for the OpenSearch cluster to be reachable..."
for i in $(seq 1 60); do
  if curl -sf "${OS_URL}/_cluster/health" >/dev/null; then break; fi
  sleep 3
  if [ "$i" = 60 ]; then echo "ERROR: ${OS_URL} not reachable." >&2; exit 1; fi
done

# --- 1. ML cluster settings (idempotent) ------------------------------------
echo "==> Applying ml-commons cluster settings (only_run_on_ml_node=${ONLY_ON_ML}, native_memory_threshold=${NATIVE_MEM})..."
curl -sf -XPUT "${OS_URL}/_cluster/settings" \
  -H 'Content-Type: application/json' -d "{
    \"persistent\": {
      \"plugins.ml_commons.only_run_on_ml_node\": \"${ONLY_ON_ML}\",
      \"plugins.ml_commons.native_memory_threshold\": \"${NATIVE_MEM}\"
    }
  }" >/dev/null
echo "    ok."

# --- helper: poll an ML task until COMPLETED, echo model_id -----------------
poll_task() {
  local task_id="$1" state resp
  for _ in $(seq 1 200); do
    resp="$(curl -s "${OS_URL}/_plugins/_ml/tasks/${task_id}")"
    state="$(echo "${resp}" | jget "['state']" || true)"
    case "${state}" in
      COMPLETED) echo "${resp}" | jget "['model_id']"; return 0 ;;
      FAILED|COMPLETED_WITH_ERROR|CANCELLED|EXPIRED|UNREACHABLE)
        echo "ERROR: task ${task_id} -> ${state}: ${resp}" >&2; return 1 ;;
      *) sleep 3 ;;
    esac
  done
  echo "ERROR: task ${task_id} timed out (last state=${state})" >&2; return 1
}

# --- 2. Look up the model by name (idempotency) -----------------------------
# Exclude chunk sub-models (they carry a chunk_number field) so we match the
# real model document.
echo "==> Looking up model '${MODEL_NAME}'..."
SEARCH_RESP="$(curl -s "${OS_URL}/_plugins/_ml/models/_search" \
  -H 'Content-Type: application/json' -d "{
    \"query\": { \"bool\": {
      \"must\":     [ { \"term\": { \"name.keyword\": \"${MODEL_NAME}\" } } ],
      \"must_not\": [ { \"exists\": { \"field\": \"chunk_number\" } } ] } },
    \"_source\": [\"model_state\"], \"size\": 1
  }")"
MODEL_ID="$(echo "${SEARCH_RESP}" | jget "['hits']['hits'][0]['_id']" || true)"

# --- 3. Register model only if not found ------------------------------------
if [ -z "${MODEL_ID:-}" ]; then
  echo "==> Registering model (this downloads the model, can take a few minutes)..."
  REG_RESP="$(curl -s -XPOST "${OS_URL}/_plugins/_ml/models/_register" \
    -H 'Content-Type: application/json' -d "{
      \"name\": \"${MODEL_NAME}\",
      \"version\": \"${MODEL_VERSION}\",
      \"model_format\": \"${MODEL_FORMAT}\"
    }")"
  REG_TASK="$(echo "${REG_RESP}" | jget "['task_id']" || true)"
  [ -n "${REG_TASK:-}" ] || { echo "ERROR: register failed. Resp: ${REG_RESP}" >&2; exit 1; }
  echo "    register task_id = ${REG_TASK}"
  MODEL_ID="$(poll_task "${REG_TASK}")"
  echo "    registered model_id = ${MODEL_ID}"
else
  echo "    model already registered: ${MODEL_ID}"
fi

# --- 4. Deploy model only if not already DEPLOYED ---------------------------
STATE="$(curl -s "${OS_URL}/_plugins/_ml/models/${MODEL_ID}" | jget "['model_state']" || true)"
if [ "${STATE:-}" != "DEPLOYED" ]; then
  echo "==> Deploying model into memory (state=${STATE:-unknown})..."
  DEP_RESP="$(curl -s -XPOST "${OS_URL}/_plugins/_ml/models/${MODEL_ID}/_deploy")"
  DEP_TASK="$(echo "${DEP_RESP}" | jget "['task_id']" || true)"
  [ -n "${DEP_TASK:-}" ] || { echo "ERROR: deploy failed. Resp: ${DEP_RESP}" >&2; exit 1; }
  poll_task "${DEP_TASK}" >/dev/null
  echo "    deployed."
else
  echo "==> Model already deployed."
fi

# Assert the model really is DEPLOYED before continuing.
FINAL="$(curl -s "${OS_URL}/_plugins/_ml/models/${MODEL_ID}" | jget "['model_state']" || true)"
[ "${FINAL:-}" = "DEPLOYED" ] || { echo "ERROR: model ${MODEL_ID} not DEPLOYED (state=${FINAL:-unknown})" >&2; exit 1; }

# --- 5. Create/update the ingest pipeline -----------------------------------
echo "==> Creating/updating ingest pipeline '${PIPELINE}'..."
curl -sf -XPUT "${OS_URL}/_ingest/pipeline/${PIPELINE}" \
  -H 'Content-Type: application/json' -d "{
    \"description\": \"Embed Nuxeo document chunks\",
    \"processors\": [
      { \"text_embedding\": { \"model_id\": \"${MODEL_ID}\", \"field_map\": { \"chunk_text\": \"embedding\" } } }
    ]
  }" >/dev/null
echo "    ok."

# --- 6. Tests: sanity-check the embedding + verify the pipeline exists -------
echo "==> Sanity check (embedding a test sentence)..."
DIM="$(curl -s -XPOST "${OS_URL}/_plugins/_ml/_predict/text_embedding/${MODEL_ID}" \
  -H 'Content-Type: application/json' \
  -d '{"text_docs":["hello world"],"return_number":true,"target_response":["sentence_embedding"]}' \
  | jget "['inference_results'][0]['output'][0]['shape'][0]" || true)"
[ -n "${DIM:-}" ] && echo "    embedding dimension = ${DIM}" || echo "    WARN: could not read embedding dimension (model is deployed, but predict returned nothing)."

echo "==> Verifying ingest pipeline '${PIPELINE}' exists..."
if curl -sf "${OS_URL}/_ingest/pipeline/${PIPELINE}" >/dev/null; then
  echo "    pipeline present."
else
  echo "    WARN: pipeline '${PIPELINE}' not found after creation." >&2
fi

cat <<EOF

============================================================================
 DONE.

 model_id: ${MODEL_ID}
 pipeline: ${PIPELINE}

 Next steps:
   1) Paste this into conf/vector-search.conf:
      nuxeo.search.client.vector.opensearch2.model.id=${MODEL_ID}
      (and set .dimension=${DIM:-384} if it differs)
   2) Start / (re)build Nuxeo:
        docker compose up -d --build nuxeo
   3) Build the vector index once:
        make reindex-vector
============================================================================
EOF
