#!/bin/bash

# ==============================================================================
# Bootstrap script to create a docker compose tooling for Nuxeo.
# ==============================================================================

NPD_REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
NUXEO_IMAGE_PREFIX="docker-private.packages.nuxeo.com/nuxeo/nuxeo:"
MONGO_VERSION="8.0"
MAILU_VERSION="2024.06"
OPENSEARCH_VERSION="2"
OPENSEARCH_IMAGE="opensearchproject/opensearch:"${OPENSEARCH_VERSION}
OPENSEARCH_DASHBOARDS_IMAGE="opensearchproject/opensearch-dashboards:"${OPENSEARCH_VERSION}
INSTALL_RPM="" # TODO: this isn't used. It's kind of an advanced topic though, so maybe that's ok.
CONNECT_URL="https://connect.nuxeo.com/nuxeo/site/"

# Check for the commands the tooling relies on. This is the first thing a user
# runs, so we check everything the whole stack needs up front (not just this
# script).
CHECKS=()
# commands required by this script and generate_clid.sh
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")
command -v awk >/dev/null || CHECKS+=("awk")
command -v grep >/dev/null || CHECKS+=("grep")
command -v cut >/dev/null || CHECKS+=("cut")
command -v tail >/dev/null || CHECKS+=("tail")
command -v mktemp >/dev/null || CHECKS+=("mktemp")
command -v readlink >/dev/null || CHECKS+=("readlink")
command -v openssl >/dev/null || CHECKS+=("openssl")
# commands needed by Makefile / check_version.sh / info.sh
command -v make >/dev/null || CHECKS+=("make")
command -v jq >/dev/null || CHECKS+=("jq")
command -v curl >/dev/null || CHECKS+=("curl")
command -v sort >/dev/null || CHECKS+=("sort")
# docker compose v2 is a separate plugin that can be missing even when docker is
# present.
docker compose version >/dev/null 2>&1 || CHECKS+=("docker-compose-plugin")

if [ ${#CHECKS[@]} -ne 0 ]
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
INSTALL_PACKAGES_DEFAULT=n
INSTALL_PACKAGES="${INSTALL_PACKAGES:-}"
if [ -z "${INSTALL_PACKAGES}" ]
then
  while true
  do
    read -p "Do you want to install packages at build time? (y|n) [${INSTALL_PACKAGES_DEFAULT}]: " INSTALL_PACKAGES
    # If not specified, use default
    if [ -z "${INSTALL_PACKAGES}" ]; then
        INSTALL_PACKAGES=${INSTALL_PACKAGES_DEFAULT}
    fi

    # Restrict input to 'y' or 'n'
    case "${INSTALL_PACKAGES}" in
      y|n)
        break
        ;;
      *)
        echo "Invalid input. Please enter 'y' or 'n', or you can press Enter to accept the default (${INSTALL_PACKAGES_DEFAULT})."
        ;;
    esac
  done
fi

# Include a mail server?
# ======================
# TODO: default "no" for now because it's new, but I suspect we will default
# this to "yes" eventually.
MAIL_SERVER_DEFAULT=n
MAIL_SERVER="${MAIL_SERVER:-}"
if [ -z "${MAIL_SERVER}" ]
then
  while true
  do
    read -p "Do you want to include a mail server? (y|n) [${MAIL_SERVER_DEFAULT}]: " MAIL_SERVER
    # If not specified, use default
    if [ -z "${MAIL_SERVER}" ]; then
        MAIL_SERVER=${MAIL_SERVER_DEFAULT}
    fi

    # Restrict input to 'y' or 'n'
    case "${MAIL_SERVER}" in
      y|n)
        break
        ;;
      *)
        echo "Invalid input. Please enter 'y' or 'n', or you can press Enter to accept the default (${MAIL_SERVER_DEFAULT})."
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

# Compose profiles
# ================
COMPOSE_PROFILES=""
MAILU_SECRET_KEY=""
MAILU_ADMIN_PW=""
if [[ "${MAIL_SERVER}" == "y" ]]
then
  COMPOSE_PROFILES="${COMPOSE_PROFILES:+${COMPOSE_PROFILES},}mail"
  MAILU_SECRET_KEY=$(openssl rand -hex 16)
  MAILU_ADMIN_PW=$(openssl rand -hex 10)
fi

# Web UI publish bind prefix; empty = 0.0.0.0. AWS generator sets "127.0.0.1:" so only the reverse proxy reaches it.
MAIL_WEB_BIND=""

# Full identifier for Nuxeo Server docker image.
NUXEO_IMAGE="${NUXEO_IMAGE_PREFIX}${nx_version}"

# ==============================================================================
# Summarize
# ==============================================================================

echo
echo "Studio project:        ${NX_STUDIO}"
echo "Build-time Packages?:  ${INSTALL_PACKAGES}"
echo "Mail server?:          ${MAIL_SERVER}"
echo "Nuxeo version:         ${nx_version}"
echo "Nuxeo Image:           ${NUXEO_IMAGE}"
echo "Studio Username:       ${STUDIO_USERNAME}"
echo "NPD Branch:            ${NPD_BRANCH}"

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

# The `init` folder needs to be writable by the container user; we have a
# feature to copy the server's default log4j2.xml out to the host.
chmod 777 ${NX_STUDIO}/init

# Install conf files
# ==================
mkdir -p ${NX_STUDIO}/conf
cp ${NX_STUDIO}/conf.d/*.conf ${NX_STUDIO}/conf

# These templates are required for our stack.
TEMPLATES="default,mongodb"

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
# Auto install OpenSearch 2.x search client
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-search-client-opensearch2"
# Auto install OpenSearch 2.x audit client
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-audit-opensearch2"

# Handle build-time vs runtime package install
if [[ "${INSTALL_PACKAGES}" == "y" ]]
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

MONGO_VERSION=${MONGO_VERSION}
MAILU_VERSION=${MAILU_VERSION}
OPENSEARCH_IMAGE=${OPENSEARCH_IMAGE}
OPENSEARCH_DASHBOARDS_IMAGE=${OPENSEARCH_DASHBOARDS_IMAGE}

COMPOSE_PROFILES=${COMPOSE_PROFILES}
MAIL_WEB_BIND=${MAIL_WEB_BIND}

FQDN=${FQDN}
STUDIO_USERNAME=${STUDIO_USERNAME}
STUDIO_CREDENTIALS=${CREDENTIALS}
EOF

if [[ "${MAIL_SERVER}" == "y" ]]
then
  MAIL_DOMAIN="mail.example.com"
  cat << EOF > ${NX_STUDIO}/.mail.env
SECRET_KEY=${MAILU_SECRET_KEY}
DOMAIN=${MAIL_DOMAIN}
HOSTNAMES=${MAIL_DOMAIN}
POSTMASTER=admin
TLS_FLAVOR=notls
ADMIN=true
INITIAL_ADMIN_ACCOUNT=mailadmin
INITIAL_ADMIN_DOMAIN=${MAIL_DOMAIN}
INITIAL_ADMIN_PW=${MAILU_ADMIN_PW}
INITIAL_ADMIN_MODE=ifmissing
WEBMAIL=roundcube
WEBDAV=none
ANTIVIRUS=none
API=false
MESSAGE_SIZE_LIMIT=50000000
RECIPIENT_DELIMITER=+
FULL_TEXT_SEARCH=off
WEBROOT_REDIRECT=/webmail
WEB_ADMIN=/admin
WEB_WEBMAIL=/webmail
SESSION_COOKIE_SECURE=False
LOG_LEVEL=INFO
TZ=Etc/UTC
CREDENTIAL_ROUNDS=12
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
docker compose pull --ignore-buildable

# Generate CLID
echo
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
echo "See https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki for docs. Hint: "
echo
echo "cd ${NX_STUDIO} && docker compose up -d"
echo