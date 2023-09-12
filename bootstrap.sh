#!/bin/bash

REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
BRANCH="master"
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
LTS_IMAGE="${DOCKER_PRIVATE}/nuxeo/nuxeo:2023"

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
    b) BRANCH=${OPTARG};;
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

# Choose image
# Cloud image is deprecated, just default to LTS
IMAGE_TYPE="LTS"
AUTO_IMAGE=""
FROM_IMAGE=""
if [ -z "${IMAGE_TYPE}" ]
then
  echo "Which image? (LTS requires a Nuxeo Docker login)"
  select lc in "Latest" "LTS"
  do
      if [[ "$lc" == "LTS" || "$lc" == "2" ]] || [[ "$lc" == "Latest" || "$lc" == "1" ]]
      then
          break
      fi
  done
else
  lc=${IMAGE_TYPE}
  AUTO_IMAGE="y"
fi
lc=$(echo "${lc}" | awk '{print tolower($0)}')
if [[ "$lc" == "lts" || "$lc" == "2" ]]
then
  echo "LTS selected"
  FROM_IMAGE=${LTS_IMAGE}
  IMAGE_TYPE="lts"
elif [[ "$lc" == "latest" || "$lc" == "1" ]]
then
  echo "Latest selected"
  FROM_IMAGE=${LATEST_IMAGE}
  IMAGE_TYPE="latest"
else
  echo "Invalid image type '${lc}', using Latest image"
  FROM_IMAGE=${LATEST_IMAGE}
  IMAGE_TYPE="latest"
fi

export FROM_IMAGE
echo ""
echo "Using Image: ${FROM_IMAGE}"

# Check Docker repo configuration
if [[ "${FROM_IMAGE}" == "${LTS_IMAGE}" ]]
then
  grep -q ${DOCKER_PRIVATE} ${HOME}/.docker/config.json
  FOUND=$?
  DOCKER=""
  if [ -z "${AUTO_IMAGE}" ] && [[ "${FOUND}" == "0" ]]
  then
    echo -n "Docker login found.  Would you like to use the existing credentials? y/n [y]: "
    read DOCKER
  fi
  if [[ ${FOUND} == "0" ]] && [[ "${DOCKER}" == "n" || "${DOCKER}" == "N" ]]
  then
    FOUND="1"
  fi
  if [[ "${FOUND}" != "0" ]]
  then
    echo "Please provide your login credentials for ${DOCKER_PRIVATE}:"
    docker login ${DOCKER_PRIVATE}
    EXEC=$?
    if [[ "${EXEC}" != "0" ]]
    then
      echo "Unable to complete docker login :-("
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

if [ "$BRANCH" = "master" ]
then
  git clone ${REPO} ${NX_STUDIO}
else
  echo "Using nuxeo-presales-docker branch ${BRANCH}"
  git clone -b ${BRANCH} ${REPO} ${NX_STUDIO}
fi

mkdir -p ${NX_STUDIO}/conf
cp ${NX_STUDIO}/conf.d/*.conf ${NX_STUDIO}/conf
echo ""

# Write system configuration
cat << EOF > ${NX_STUDIO}/conf/system.conf
# Host Configuration
session.timeout=600
nuxeo.url=http://${FQDN}:8080/nuxeo

# Enable "select all" by default
nuxeo.selection.selectAllEnabled=true

# Templates
nuxeo.templates=default,mongodb
EOF

# Make sure we always have a UI installed
AUTO_PACKAGES="nuxeo-web-ui"
# Auto install Nuxeo Explorer because the website is unusable
AUTO_PACKAGES="${AUTO_PACKAGES} platform-explorer"

# Write environment file
cat << EOF > ${NX_STUDIO}/.env
APPLICATION_NAME=${NX_STUDIO}
PROJECT_NAME=${PROJECT_NAME}

NUXEO_IMAGE=${FROM_IMAGE}

CONNECT_URL=https://connect.nuxeo.com/nuxeo/site/

NUXEO_DEV=true
NUXEO_PORT=8080
NUXEO_PACKAGES=${STUDIO_PACKAGE} ${AUTO_PACKAGES} ${NUXEO_PACKAGES:-}

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
docker pull --quiet ${FROM_IMAGE}
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
echo "> Share your configuration:"
echo "IMAGE_TYPE=${IMAGE_TYPE} NUXEO_PACKAGES=\"${NUXEO_PACKAGES:-}\" FQDN=${FQDN} NX_STUDIO=${NX_STUDIO} NX_STUDIO_VER=${NX_STUDIO_VER} bash -c \"\$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/${BRANCH}/bootstrap.sh)\""
echo ""

# Display startup instructions
make -e info
if [ -e notes.txt ]
then
  cat notes.txt
fi
