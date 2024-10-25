#!/bin/bash

# ==============================================================================
# Bootstrap script to create a docker compose tooling for Nuxeo.
# ==============================================================================

NPD_REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
NUXEO_IMAGE_PREFIX="docker-private.packages.nuxeo.com/nuxeo/nuxeo:"
MONGO_VERSION="6.0"
OPENSEARCH_VERSION="1.3.19"
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

# Nuxeo Version
# =============
NX_VERSION_DEFAULT="2023"
nx_version="${NX_VERSION:-}"
if [ -z "${nx_version}" ]
then
  read -p "Nuxeo Version [${NX_VERSION_DEFAULT}]: " nx_version
  nx_version=${nx_version:-${NX_VERSION_DEFAULT}}
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

# If no HF level is specified, just use latest Dockerfile.
if [[ $nx_version == "2023" ]]
then
  DOCKERFILE="build_nuxeo/Dockerfile"
fi

# If HF level has been specified we need to select the correct Dockerfile.
if [ -z "${DOCKERFILE}" ]
then
  # If Nuxeo verion is 2023.19 or earlier, use Rocky Linux Dockerfile
  TARGET_VERSION="2023.19"
  # Compare the two versions using sort (code from ChatGPT)
  if [ "$(printf '%s\n' "$nx_version" "$TARGET_VERSION" | sort -V | head -n 1)" = "$nx_version" ]; then
    DOCKERFILE="build_nuxeo/Dockerfile.hf19"
  else
    DOCKERFILE="build_nuxeo/Dockerfile"
  fi
fi


# ==============================================================================
# Summarize
# ==============================================================================

echo
echo "Studio project:        ${NX_STUDIO}"
echo "Build-time Packages?:  ${INSTALL_PACKAGES}"
echo "Nuxeo version:         ${nx_version}"
echo "Nuxeo Image:           ${NUXEO_IMAGE}"
echo "Studio Username:       ${STUDIO_USERNAME}"
echo "NPD Branch:            ${NPD_BRANCH}"
echo "Dockerfile:            ${DOCKERFILE}"

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

# Handle build-time vs runtime package install
if ${INSTALL_PACKAGES}
then
  ENV_BUILD_PACKAGES="${NX_STUDIO} ${AUTO_PACKAGES} ${NUXEO_PACKAGES:-}"
  ENV_NUXEO_PACKAGES="${NX_STUDIO}"
else
  ENV_BUILD_PACKAGES="${AUTO_PACKAGES}"
  ENV_NUXEO_PACKAGES="${NX_STUDIO} ${NUXEO_PACKAGES:-}"
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
OPENSEARCH_IMAGE=${OPENSEARCH_IMAGE}
OPENSEARCH_DASHBOARDS_IMAGE=${OPENSEARCH_DASHBOARDS_IMAGE}

FQDN=${FQDN}
STUDIO_USERNAME=${STUDIO_USERNAME}
STUDIO_CREDENTIALS=${CREDENTIALS}
EOF

# Use correct Dockerfile for Oracle vs Rocky Linux
# Use sed to replace the value of 'dockerfile' for Nuxeo with the new value (for macOS)
sed -i '' "s|dockerfile: build_nuxeo/Dockerfile|dockerfile: $DOCKERFILE|" "${NX_STUDIO}/docker-compose.yml"

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