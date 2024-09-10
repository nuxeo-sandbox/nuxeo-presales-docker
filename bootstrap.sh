#!/bin/bash

NPD_REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
NPD_BRANCH="master"
NUXEO_IMAGE="docker-private.packages.nuxeo.com/nuxeo/nuxeo:2023.6"

MONGO_VERSION="6.0"
OPENSEARCH_VERSION="1.3.11"

OPENSEARCH_IMAGE="opensearchproject/opensearch:"${OPENSEARCH_VERSION}
OPENSEARCH_DASHBOARDS_IMAGE="opensearchproject/opensearch-dashboards:"${OPENSEARCH_VERSION}

CHECKS=()
# Check for commands used in this script
command -v awk >/dev/null || CHECKS+=("awk")
command -v make >/dev/null || CHECKS+=("make")
command -v envsubst >/dev/null || CHECKS+=("envsubst")
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")

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

# Allow use of a different branch, useful for testing
while getopts b: flag
do
  case "${flag}" in
    b) NPD_BRANCH=${OPTARG};;
  esac
done

# Directions for image setup
cat << EOM
 _ __  _   ___  _____  ___
| '_ \| | | \ \/ / _ \/ _ \\
| | | | |_| |>  <  __/ (_) |
|_| |_|\__,_/_/\_\___|\___/

Nuxeo Docker Compose Bootstrap

Requirements:

* A Nuxeo Connect Account (https://connect.nuxeo.com/)
* A Nuxeo Connect token (https://connect.nuxeo.com/nuxeo/site/connect/tokens)
* A Nuxeo Studio project id
* Sonatype User Token credentials (https://packages.nuxeo.com/#user/usertoken)

If you are on a Mac, you have the option to save your Connect Token in your
Keychain. If you do so, note that a dialog box will pop up to verify credential
access whenever you use this script.

This script builds a custom Nuxeo docker image. This may consume a lot of
bandwidth and may take a bit of time. Please be patient. At the end of the
script, additional instructions will be displayed.

EOM

# Prompt for studio project name
NX_STUDIO="${NX_STUDIO:-}"
INSTALL_RPM=""
while [ -z "${NX_STUDIO}" ]
do
  echo -n "Studio Project ID: "
  read NX_STUDIO
done

if [ -e ${NX_STUDIO} ]
then
  echo "Hmm, the directory ${PWD}/${NX_STUDIO} already exists.  I'm going to exit and let you sort that out."
  exit 3
fi

# Prompt for project version
PROJECT_NAME=$(echo "${NX_STUDIO}" | awk '{print tolower($0)}')
STUDIO_PACKAGE=""
NX_STUDIO_VER="${NX_STUDIO_VER:-}"
if [ -z "${NX_STUDIO_VER}" ]
then
  echo -n "Version: [0.0.0-SNAPSHOT] "
  read NX_STUDIO_VER
fi
if [ -z "${NX_STUDIO_VER}" ]
then
  NX_STUDIO_VER="0.0.0-SNAPSHOT"
fi
if [ -n "${NX_STUDIO}" ]
then
  STUDIO_PACKAGE="${NX_STUDIO}-${NX_STUDIO_VER}"
  echo "Using Nuxeo Studio package: ${STUDIO_PACKAGE}"
fi

# Prompt for packages in build
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

# Prompt for host name
FQDN="${FQDN:-}"
if [ -z "${FQDN}" ]
then
  echo -n "Hostname: [localhost] "
  read FQDN
fi
if [ -z "${FQDN}" ]
then
  FQDN="localhost"
fi

export NUXEO_IMAGE
echo ""
echo "Using Image: ${NUXEO_IMAGE}"

# If the Nuxeo image is private, need Docker login.
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
if [[ "${NUXEO_IMAGE}" == "${DOCKER_PRIVATE}"* ]]
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

# Prompt for Studio Login
STUDIO_USERNAME=${STUDIO_USERNAME:-}
while [ -z "${STUDIO_USERNAME}" ]
do
  echo -n "Studio username: "
  read STUDIO_USERNAME
done

# Check to see if password exists
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

CREDENTIALS=${CREDENTIALS:-}
while [ -z "${CREDENTIALS}" ]
do
  echo -n "Studio token: "
  read -s CREDENTIALS
  echo ""
done

# Create project folder
echo ""
echo "Cloning configuration: ${PWD}/${NX_STUDIO}"

if [ "$NPD_BRANCH" = "master" ]
then
  git clone ${NPD_REPO} ${NX_STUDIO}
else
  echo "Using nuxeo-presales-docker branch ${NPD_BRANCH}"
  git clone -b ${NPD_BRANCH} ${NPD_REPO} ${NX_STUDIO}
fi

mkdir -p ${NX_STUDIO}/conf
cp ${NX_STUDIO}/conf.d/*.conf ${NX_STUDIO}/conf
echo ""

TEMPLATES="default,mongodb"

# Write system configuration
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

# Make sure we always have a UI installed
AUTO_PACKAGES="nuxeo-web-ui"
# Auto install Nuxeo Explorer because the website is often unusable
AUTO_PACKAGES="${AUTO_PACKAGES} platform-explorer"

if ${INSTALL_PACKAGES}
then
  ENV_BUILD_PACKAGES="${STUDIO_PACKAGE} ${AUTO_PACKAGES} ${NUXEO_PACKAGES:-}"
  ENV_NUXEO_PACKAGES="${STUDIO_PACKAGE}"
else
  ENV_BUILD_PACKAGES="${AUTO_PACKAGES}"
  ENV_NUXEO_PACKAGES="${STUDIO_PACKAGE} ${NUXEO_PACKAGES:-}"
fi

# Write environment file
cat << EOF > ${NX_STUDIO}/.env
APPLICATION_NAME=${NX_STUDIO}
PROJECT_NAME=${PROJECT_NAME}

NUXEO_IMAGE=${NUXEO_IMAGE}

CONNECT_URL=https://connect.nuxeo.com/nuxeo/site/

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

# Run everything in NX_STUDIO dir
cd ${NX_STUDIO}

# Pull images
echo "Please wait, getting things ready..."
docker pull --quiet ${NUXEO_IMAGE}
echo " pulling other services..."
docker compose pull
echo ""

# Generate CLID
echo "Generating CLID..."
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
echo ""

# Build image (may use CLID generated in previous step)
echo "Building your custom image(s)..."
docker compose build
echo ""

# Display a sharable config
echo "Share your configuration:"
echo "INSTALL_PACKAGES=${INSTALL_PACKAGES} NUXEO_PACKAGES=\"${NUXEO_PACKAGES:-}\" FQDN=${FQDN} NX_STUDIO=${NX_STUDIO} NX_STUDIO_VER=${NX_STUDIO_VER} bash -c \"\$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/${NPD_BRANCH}/bootstrap.sh)\""
echo ""

# Display startup instructions
make -e info
if [ -e notes.txt ]
then
  cat notes.txt
fi
