#!/bin/bash

# ==============================================================================
# Bootstrap script to create a docker compose tooling for Nuxeo.
# ==============================================================================

NPD_REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
NUXEO_IMAGE_PREFIX="docker-private.packages.nuxeo.com/nuxeo/nuxeo:"
MONGO_VERSION="8.0"
# OpenSearch 3.7 hosts the keyword/BM25 "main" index + audit AND (when the
# vector package is installed) the vector index (k-NN + ML + neural-search).
OPENSEARCH_VERSION="3.7.0"
OPENSEARCH_IMAGE="opensearchproject/opensearch:"${OPENSEARCH_VERSION}
OPENSEARCH_DASHBOARDS_IMAGE="opensearchproject/opensearch-dashboards:"${OPENSEARCH_VERSION}
INSTALL_RPM="" # TODO: this isn't used. It's kind of an advanced topic though, so maybe that's ok.
CONNECT_URL="https://connect.nuxeo.com/nuxeo/site/"

# Check for commands used in this script
CHECKS=()
command -v awk >/dev/null || CHECKS+=("awk")
command -v make >/dev/null || CHECKS+=("make")
command -v envsubst >/dev/null || CHECKS+=("envsubst")
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")
command -v sort >/dev/null || CHECKS+=("sort")
command -v head >/dev/null || CHECKS+=("head")
command -v sed >/dev/null || CHECKS+=("sed")

if [ $CHECKS ]
then
  echo "Please install the following programs for your platform:"
  echo ${CHECKS[@]}
  exit 1
fi

docker info >/dev/null
RUNNING=$?
if [ "${RUNNING}" != "0" ]
then
  echo "Docker does not appear to be running, please start Docker."
  exit 2
fi

# Allow use of a different branch, useful for testing, default is `master`.

# Allow passing NPD branch as a param.
NPD_BRANCH=${NPD_BRANCH:-master}

# Allow use of a different branch with a flag.
while getopts b: flag
do
  case "${flag}" in
    b) NPD_BRANCH=${OPTARG};;
  esac
done

# ==============================================================================
# User inputs
# ==============================================================================

# Studio Project
# ==============
NX_STUDIO="${NX_STUDIO:-}"
# Required, loop until we get a value.
while [ -z "${NX_STUDIO}" ]
do
  echo -n "Studio Project ID: "
  read NX_STUDIO
done

# We don't want to run this script on existing folders...
if [ -e ${NX_STUDIO} ]
then
  echo "Hmm, the directory ${PWD}/${NX_STUDIO} already exists.  I'm going to exit and let you sort that out."
  exit 3
fi

# Install Packages at build time?
# ===============================
INSTALL_PACKAGES_DEFAULT=false
INSTALL_PACKAGES="${INSTALL_PACKAGES:-}"
if [ -z "${INSTALL_PACKAGES}" ]
then
  while true
  do
    read -p "Do you want to install packages at build time? [${INSTALL_PACKAGES_DEFAULT}]: " INSTALL_PACKAGES
    # If not specified, use default
    if [ -z "${INSTALL_PACKAGES}" ]; then
        INSTALL_PACKAGES=${INSTALL_PACKAGES_DEFAULT}
    fi

    # Restrict input to 'true' or 'false'
    case "${INSTALL_PACKAGES}" in
      true|false)
        break
        ;;
      *)
        echo "Invalid input. Please enter 'true' or 'false', or you can press Enter to accept the default (${INSTALL_PACKAGES_DEFAULT})."
        ;;
    esac
  done
fi

# Install ffmpeg at build time?
# ==============================
# ffmpeg (+ codecs) is a heavy build step. Default true keeps previous behavior;
# set to false to skip it and speed up the custom image build.
INSTALL_FFMPEG_DEFAULT=true
INSTALL_FFMPEG="${INSTALL_FFMPEG:-}"
if [ -z "${INSTALL_FFMPEG}" ]
then
  while true
  do
    read -p "Install ffmpeg (+ codecs) at build time? [${INSTALL_FFMPEG_DEFAULT}]: " INSTALL_FFMPEG
    # If not specified, use default
    if [ -z "${INSTALL_FFMPEG}" ]; then
        INSTALL_FFMPEG=${INSTALL_FFMPEG_DEFAULT}
    fi

    # Restrict input to 'true' or 'false'
    case "${INSTALL_FFMPEG}" in
      true|false)
        break
        ;;
      *)
        echo "Invalid input. Please enter 'true' or 'false', or you can press Enter to accept the default (${INSTALL_FFMPEG_DEFAULT})."
        ;;
    esac
  done
fi

# Nuxeo Version
# =============
NX_VERSION_DEFAULT="2025"
nx_version="${NX_VERSION:-}"
if [ -z "${nx_version}" ]
then
  read -p "Nuxeo Version [${NX_VERSION_DEFAULT}]: " nx_version
  nx_version=${nx_version:-${NX_VERSION_DEFAULT}}
fi
if [[ "$nx_version" != "$NX_VERSION_DEFAULT"* ]]; then
  echo "Invalid Nuxeo Version. It should starts with $NX_VERSION_DEFAULT"
  exit 1
fi

# Optional features
# =================
# Semantic / vector search (OpenSearch 3.7 + vector client). Requires the moving
# nuxeo-search-client-opensearch2-vector-*.zip dropped in ./nuxeo_packages/.
ENABLE_VECTOR_DEFAULT=false
ENABLE_VECTOR="${ENABLE_VECTOR:-}"
if [ -z "${ENABLE_VECTOR}" ]
then
  while true
  do
    read -p "Enable semantic / vector search? [${ENABLE_VECTOR_DEFAULT}]: " ENABLE_VECTOR
    ENABLE_VECTOR=${ENABLE_VECTOR:-${ENABLE_VECTOR_DEFAULT}}
    case "${ENABLE_VECTOR}" in
      true|false) break ;;
      *) echo "Please enter 'true' or 'false' (or Enter for ${ENABLE_VECTOR_DEFAULT})." ;;
    esac
  done
fi

# Nuxeo MCP server (optional, built from a local clone of nuxeo/nuxeo-mcp-server).
ENABLE_MCP_DEFAULT=false
ENABLE_MCP="${ENABLE_MCP:-}"
if [ -z "${ENABLE_MCP}" ]
then
  while true
  do
    read -p "Enable Nuxeo MCP server? [${ENABLE_MCP_DEFAULT}]: " ENABLE_MCP
    ENABLE_MCP=${ENABLE_MCP:-${ENABLE_MCP_DEFAULT}}
    case "${ENABLE_MCP}" in
      true|false) break ;;
      *) echo "Please enter 'true' or 'false' (or Enter for ${ENABLE_MCP_DEFAULT})." ;;
    esac
  done
fi

# If MCP is enabled, we need the path to a local nuxeo-mcp-server clone and,
# optionally, the branch to build.
NUXEO_MCP_SRC="${NUXEO_MCP_SRC:-}"
NUXEO_MCP_BRANCH="${NUXEO_MCP_BRANCH:-}"
if [ "${ENABLE_MCP}" == "true" ]
then
  while [ -z "${NUXEO_MCP_SRC}" ]
  do
    echo -n "Absolute path to your local nuxeo-mcp-server clone: "
    read NUXEO_MCP_SRC
  done
  if [ -z "${NUXEO_MCP_BRANCH}" ]
  then
    read -p "nuxeo-mcp-server branch to build (Enter = current checkout): " NUXEO_MCP_BRANCH
  fi
fi

# ==============================================================================
# Credentials
# ==============================================================================

# Nexus
# =====
# If the Nuxeo image is private, need Docker login.
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
if [[ "${NUXEO_IMAGE_PREFIX}" == "${DOCKER_PRIVATE}"* ]]
then
  # Check to see if user already has saved credentials
  grep -q ${DOCKER_PRIVATE} ${HOME}/.docker/config.json
  FOUND=$?
  if [[ "${FOUND}" != "0" ]]
  then
    docker login ${DOCKER_PRIVATE}
    DOCKER_LOGIN_OK=$?
    if [[ "${DOCKER_LOGIN_OK}" != "0" ]]
    then
      echo "Unable to complete docker login"
      exit 1
    fi
  fi
fi

# NOS
# ===
STUDIO_USERNAME=${STUDIO_USERNAME:-}
while [ -z "${STUDIO_USERNAME}" ]
do
  echo -n "Studio username: "
  read STUDIO_USERNAME
done

# Get Studio token from KeyChain on macOs
MACFOUND="false"
if [[ "${OSTYPE}" == "darwin"* ]]
then
  password=$(security find-generic-password -w -a ${STUDIO_USERNAME} -s studio 2>/dev/null)
  CHECK=$?
  if [[ "$CHECK" != "0" ]]
  then
    echo "No password found in MacOS keychain, please provide your credentials below."
  else
    MACFOUND="true"
    CREDENTIALS="${password}"
  fi
fi

# Save Studio token to Keychain on macOS
if [[ "${MACFOUND}" == "false" && "${OSTYPE}" == "darwin"* ]]
then
  echo -n "Save the Nuxeo Studio token in your keychain? y/n [y]: "
  read SAVEIT

  CHECK="1"
  if [[ -z "${SAVEIT}" || "${SAVEIT}" == "y" || "${SAVEIT}" == "Y" ]]
  then
    echo ""
    echo "You will be prompted to enter your token twice.  After you have saved your token, you will be prompted for your login password in a dialog box."
    security add-generic-password -T "" -a ${STUDIO_USERNAME} -s studio -w
    CHECK=$?
  fi

  if [[ "$CHECK" == "0" ]]
  then
    echo ""
    echo "A dialog box will now pop up to verify your credentials.  Please enter your login password.  The login password will not be visible to this script."
    CREDENTIALS=$(security find-generic-password -w -a ${STUDIO_USERNAME} -s studio )
  fi
fi

# If all else fails, just ask the user to enter the token
CREDENTIALS=${CREDENTIALS:-}
while [ -z "${CREDENTIALS}" ]
do
  echo -n "Studio token: "
  read -s CREDENTIALS
  echo ""
done

# ==============================================================================
# Other params
# ==============================================================================

# This value is appended to custom image names.
PROJECT_NAME=$(echo "${NX_STUDIO}" | awk '{print tolower($0)}')

# Host
# ====
FQDN="${FQDN:-}"
if [ -z "${FQDN}" ]
then
  FQDN="localhost"
fi

# Full identifier for Nuxeo Server docker image.
NUXEO_IMAGE="${NUXEO_IMAGE_PREFIX}${nx_version}"

# ==============================================================================
# Summarize
# ==============================================================================

echo
echo "Studio project:        ${NX_STUDIO}"
echo "Build-time Packages?:  ${INSTALL_PACKAGES}"
echo "Install ffmpeg?:       ${INSTALL_FFMPEG}"
echo "Nuxeo version:         ${nx_version}"
echo "Nuxeo Image:           ${NUXEO_IMAGE}"
echo "Studio Username:       ${STUDIO_USERNAME}"
echo "NPD Branch:            ${NPD_BRANCH}"
echo "Vector search:         ${ENABLE_VECTOR}"
echo "Nuxeo MCP server:      ${ENABLE_MCP}"
if [ "${ENABLE_MCP}" == "true" ]
then
  echo "  MCP source:          ${NUXEO_MCP_SRC}"
  echo "  MCP branch:          ${NUXEO_MCP_BRANCH:-<current checkout>}"
fi

echo
echo "Here's what will happen next:"
echo
echo "* Scaffold a folder for your stack"
echo "* Pull docker images"
echo "* Generate CLID"
echo "* Build custom images"

echo
read -p "Ready? (y|n) [y]: " response
response=${response:-y}
if [[ "$response" != "y" ]]
then
  exit 0
fi

echo
echo "Please wait, getting things ready..."

# ==============================================================================
# Do the things
# ==============================================================================

# Clone NPD to scaffold project folder...
echo
echo "================================================================================"
echo "Scaffolding stack folder..."
echo "================================================================================"
echo
git clone -b ${NPD_BRANCH} ${NPD_REPO} ${NX_STUDIO}

# Install conf files
# ==================
mkdir -p ${NX_STUDIO}/conf
# Always install core.conf (opensearch2 keyword client + MongoDB).
cp ${NX_STUDIO}/conf.d/core.conf ${NX_STUDIO}/conf
# vector-search.conf is only relevant when the vector package is installed;
# copying it without the package would reference a missing template.
if [ "${ENABLE_VECTOR}" == "true" ]
then
  cp ${NX_STUDIO}/conf.d/vector-search.conf ${NX_STUDIO}/conf
fi

# Make sure the local packages folder exists (used by the Docker build context,
# and where you drop the vector search client .zip).
mkdir -p ${NX_STUDIO}/nuxeo_packages

# These templates are required for our stack.
TEMPLATES="default,mongodb"

# Search templates: opensearch2 keyword + audit. These ship in the 2025.22 base
# image, so they are safe to add here (generate_clid.sh runs nuxeoctl against the
# BASE image with this conf mounted).
#
# The VECTOR template (opensearch2-vector-search-client) is intentionally NOT
# added here: it only exists once the nuxeo-search-client-opensearch2-vector
# package is baked into the CUSTOM image. Adding it now would make CLID
# generation fail on a missing template. It is appended to system.conf AFTER
# generate_clid.sh has run (see the "Append the vector template" step below).
SEARCH_TEMPLATES="opensearch2-audit,opensearch2-search-client"

# Scaffold system.conf
cat << EOF > ${NX_STUDIO}/conf/system.conf
# Host Configuration
session.timeout=600
nuxeo.url=http://${FQDN}:8080/nuxeo

# WebUI
# Enable "select all" by default
nuxeo.selection.selectAllEnabled=true
# Fix WEBUI-976
nuxeo.analytics.documentDistribution.disableThreshold=10000

# Templates
nuxeo.append.templates.system=${TEMPLATES}
nuxeo.append.templates.search=${SEARCH_TEMPLATES}
EOF

# Install .env
# ============
# Make sure we always have a UI installed
AUTO_PACKAGES="nuxeo-web-ui"
# Auto install Nuxeo Explorer because the website is often unusable
AUTO_PACKAGES="${AUTO_PACKAGES} platform-explorer"
# Auto install Nuxeo API Playground for easier API testing
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-api-playground"
# Auto install Nuxeo Admin Console for easier administration
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-admin-console"
# Auto install OpenSearch 2.x audit client (ships in the 2025.22 image)
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-audit-opensearch2"
# Auto install OpenSearch 2.x search client (ships in the 2025.22 image)
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-search-client-opensearch2"

# Handle build-time vs runtime package install
if ${INSTALL_PACKAGES}
then
  ENV_BUILD_PACKAGES="${NX_STUDIO}-0.0.0-SNAPSHOT ${AUTO_PACKAGES} ${NUXEO_PACKAGES:-}"
  ENV_NUXEO_PACKAGES="${NX_STUDIO}"
else
  ENV_BUILD_PACKAGES="${AUTO_PACKAGES}"
  ENV_NUXEO_PACKAGES="${NX_STUDIO}-0.0.0-SNAPSHOT ${NUXEO_PACKAGES:-}"
fi

# Write .env file
cat << EOF > ${NX_STUDIO}/.env
APPLICATION_NAME=${NX_STUDIO}
PROJECT_NAME=${PROJECT_NAME}

NUXEO_IMAGE=${NUXEO_IMAGE}

CONNECT_URL=${CONNECT_URL}

NUXEO_DEV=true
NUXEO_PORT=8080

# These packages will be included in the custom image build
BUILD_PACKAGES=${ENV_BUILD_PACKAGES}

# These packages will be installed at startup
NUXEO_PACKAGES=${ENV_NUXEO_PACKAGES}

INSTALL_RPM=${INSTALL_RPM}

# Install ffmpeg (+ codecs) in the custom image build (true|false).
INSTALL_FFMPEG=${INSTALL_FFMPEG}

MONGO_VERSION=${MONGO_VERSION}
OPENSEARCH_IMAGE=${OPENSEARCH_IMAGE}
OPENSEARCH_DASHBOARDS_IMAGE=${OPENSEARCH_DASHBOARDS_IMAGE}

# JVM heaps (tune to your Docker Desktop memory budget; total ~6-8 GB).
# OpenSearch 3.7 serves both indexes and runs the CPU embedding model.
NUXEO_HEAP=2g
OS_HEAP=3g

FQDN=${FQDN}
STUDIO_USERNAME=${STUDIO_USERNAME}
STUDIO_CREDENTIALS=${CREDENTIALS}
EOF

# Vector search extras (embedding model registration script parameters)
if [ "${ENABLE_VECTOR}" == "true" ]
then
  cat << EOF >> ${NX_STUDIO}/.env

# -----------------------------------------------------------------------------
# Semantic / vector search - embedding model registration
# (used ONLY by scripts/register-embedding-model.sh)
# -----------------------------------------------------------------------------
# Multilingual MiniLM (384 dims, ~50 languages). English-only faster alternative
# (dimension stays 384): huggingface/sentence-transformers/all-MiniLM-L6-v2
EMBEDDING_MODEL_NAME=huggingface/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
EMBEDDING_MODEL_VERSION=1.0.1
EMBEDDING_MODEL_FORMAT=TORCH_SCRIPT
EOF
fi

# MCP server extras (build context path + branch)
if [ "${ENABLE_MCP}" == "true" ]
then
  cat << EOF >> ${NX_STUDIO}/.env

# -----------------------------------------------------------------------------
# Nuxeo MCP server (profile "mcp"). Built from a local nuxeo-mcp-server clone.
# The MCP container reaches Nuxeo at http://nuxeo:8080/nuxeo (basic auth) and is
# published on 127.0.0.1:8181 for a host-side "opencode serve".
# NUXEO_MCP_BRANCH is read ONLY by scripts/build-nuxeo-mcp.sh, not by compose.
# -----------------------------------------------------------------------------
NUXEO_MCP_SRC=${NUXEO_MCP_SRC}
NUXEO_MCP_BRANCH=${NUXEO_MCP_BRANCH}

# Admin credentials the MCP server uses to call Nuxeo (Basic auth). NOT stored
# here on purpose: pass them INLINE when you start the MCP server, e.g.
#   NUXEO_MCP_USERNAME=Administrator NUXEO_MCP_PASSWORD=<pwd> make mcp-build
# If omitted, docker-compose.yml defaults them to Administrator/Administrator.
# Uncomment below only if you prefer to persist them (less "inline only"):
#NUXEO_MCP_USERNAME=Administrator
#NUXEO_MCP_PASSWORD=Administrator
EOF
fi

# Run commands
# ============

# Run everything in project dir
cd ${NX_STUDIO}

# Pull images
echo
echo "================================================================================"
echo "Pulling ${NUXEO_IMAGE}..."
echo "================================================================================"
echo
docker pull ${NUXEO_IMAGE}

echo
echo "================================================================================"
echo "Pulling other images..."
echo "================================================================================"
echo
docker compose pull

# Generate CLID
echo "================================================================================"
echo "Generating CLID..."
echo "================================================================================"
echo
./generate_clid.sh
EC=$?
if [[ "${EC}" == "1" ]]
then
  echo "Something is misconfigured or missing in your .env file, please fix and try again."
  exit 1
elif [[ "${EC}" == "2" ]]
then
  echo "Your studio token does not appear to be correct.  Please check and try again."
  exit 2
fi

# Append the vector template (AFTER CLID generation)
# ==================================================
# generate_clid.sh runs nuxeoctl against the BASE image with ./conf mounted, so
# ./conf must only reference templates present in that base image. The vector
# template (opensearch2-vector-search-client) ships in the vector package baked
# into the CUSTOM image, not the base image; so we add it to system.conf only
# now that CLID generation is done. We use a dedicated `nuxeo.append.templates.*`
# key (any suffix is aggregated by Nuxeo) to avoid rewriting the existing line.
if [ "${ENABLE_VECTOR}" == "true" ]
then
  cat << EOF >> ${NX_STUDIO}/conf/system.conf

# Vector search template - appended after CLID generation (see bootstrap.sh).
nuxeo.append.templates.vector=opensearch2-vector-search-client
EOF
fi

# Build images
echo
echo "================================================================================"
echo "Building your custom image(s)..."
echo "================================================================================"
echo
docker compose build

echo
echo "================================================================================"
echo "Installation complete."
echo "================================================================================"

echo
echo "See https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki for docs."
echo

if [ "${ENABLE_VECTOR}" == "true" ]
then
  echo "Semantic / vector search is ENABLED. Before starting Nuxeo:"
  echo "  0. cd ${NX_STUDIO}"
  echo "  1. docker compose up -d mongo opensearch    # wait until healthy"
  echo "  2. ./scripts/register-embedding-model.sh    # prints a model_id"
  echo "  3. Paste the model_id into conf/vector-search.conf"
  echo "  4. Drop the vector client .zip in ./nuxeo_packages/"
  echo "  5. docker compose up -d --build nuxeo"
  echo "  6. NUXEO_USER=Administrator NUXEO_PWD=<admin-pwd> make reindex-vector   # one-time: build the nuxeo-vector index"
  echo "  7. make check-indices                       # expect 'nuxeo' and 'nuxeo-vector'"
  echo
  echo "  Credentials for step 6 are passed INLINE (default Administrator/Administrator if omitted)."
  echo "  Use the 'VAR=val make ...' prefix form, NOT 'make ... VAR=val'."
  echo
else
  echo "Hint:"
  echo "  cd ${NX_STUDIO} && docker compose up -d"
  echo
fi

if [ "${ENABLE_MCP}" == "true" ]
then
  echo "Nuxeo MCP server is ENABLED (profile \"mcp\", off by default). To start it:"
  echo "  cd ${NX_STUDIO}"
  echo "  NUXEO_MCP_USERNAME=Administrator NUXEO_MCP_PASSWORD=<admin-pwd> make mcp-build   # builds the branch + starts on 127.0.0.1:8181"
  echo "  curl http://127.0.0.1:8181/health"
  echo
  echo "  Credentials are passed INLINE (default Administrator/Administrator if omitted)."
  echo "  Use the 'VAR=val make ...' prefix form, NOT 'make ... VAR=val'."
  echo
fi
