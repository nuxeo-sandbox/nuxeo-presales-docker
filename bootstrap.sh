#!/bin/bash

REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
LTS_IMAGE="${DOCKER_PRIVATE}/nuxeo/nuxeo:2021"
CLOUD_IMAGE="docker.packages.nuxeo.com/nuxeo/nuxeo:latest"

MONGO_VERSION="4.4"
ELASTIC_VERSION="7.9.3"

CHECKS=()
# Check for commands used in this script
command -v make >/dev/null || CHECKS+=("make")
command -v envsubst >/dev/null || CHECKS+=("envsubst")
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")
command -v docker-compose >/dev/null || CHECKS+=("docker-compose")

if [ $CHECKS ]
then
  echo "Please install the following programs for your platform:"
  echo ${CHECKS[@]}
  exit 1
fi

# Directions for image setup
cat << EOM
 _ __  _   ___  _____  ___
| '_ \| | | \ \/ / _ \/ _ \\
| | | | |_| |>  <  __/ (_) |
|_| |_|\__,_/_/\_\___|\___/

Nuxeo Docker Compose Bootstrap

This script will ask you for your Studio Project ID, Version (default is master), 
and configured hostname (default is 'localhost').

Need an account or project?  Go to https://connect.nuxeo.com/

You can then choose between the Cloud (public) and LTS (private) images.  If LTS
is selected, you will need to use your Sonatype User Token credentials to log into
the repository.  Navigate to https://packages.nuxeo.com/ and use the "Sign In"
link in the upper right to log into the system.  Once logged in, access your user
token with this link: https://packages.nuxeo.com/#user/usertoken - you may create,
access existing token, or reset the token here.  Your "token name code" is your
docker username and your "token pass code" is your password.

The next set of prompts will ask for your Studio username and Studio token. 
Please obtain the token from https://connect.nuxeo.com/nuxeo/site/connect/tokens

If you are on a Mac, you have the option to save your token in your keychain.  If
you choose to do so, a dialog box will pop up to verify credential access when you
use this script.

At this point, your configuration will be completed and the Nuxeo images will be
downloaded and built.  This may consume a lot of bandwidth and may take a bit of
time.  Please be patient.  At the end of the script, additional instructions will
be displayed.

EOM

# Prompt for studio project name
NX_STUDIO=""
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
STUDIO_PACKAGE=""
NX_STUDIO_VER=""
echo -n "Version: [0.0.0-SNAPSHOT] "
read NX_STUDIO_VER
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
FQDN=""
echo -n "Hostname: [localhost] "
read FQDN
if [ -z "${FQDN}" ]
then
  FQDN="localhost"
fi

# Choose image
FROM_IMAGE=${CLOUD_IMAGE}
echo "Which image? (LTS requires a Nuxeo Docker login)"
select lc in "Cloud" "LTS"
do
    if [[ "$lc" == "LTS" || "$lc" == "2" ]]
    then
        echo "LTS selected"
        FROM_IMAGE=${LTS_IMAGE}
        break
    elif [[ "$lc" == "Cloud" || "$lc" == "1" ]]
    then
        echo "Cloud selected"
        FROM_IMAGE=${CLOUD_IMAGE}
        break
    fi
done

export FROM_IMAGE
echo ""
echo "Using Image: ${FROM_IMAGE}"

# Check Docker repo configuration
if [[ "${FROM_IMAGE}" == "${LTS_IMAGE}" ]]
then
  grep -q ${DOCKER_PRIVATE} ${HOME}/.docker/config.json
  FOUND=$?
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

echo -n "Add Nuxeo Web UI to your configuration? y/n [y]: "
read WEBUI

if [[ -z "${WEBUI}" || "${WEBUI}" == "y" || "${WEBUI}" == "Y" ]]
then
  STUDIO_PACKAGE="${STUDIO_PACKAGE} nuxeo-web-ui"
fi

# Prompt for Studio Login
while [ -z "${STUDIO_USERNAME}" ]
do
  echo -n "Studio username: "
  read STUDIO_USERNAME
done

# Check to see if password exists
MACFOUND="false"
if [[ "${OSTYPE}" == "darwin"* ]]
then
  password=$( security find-generic-password -w -a ${STUDIO_USERNAME} -s studio 2>/dev/null)
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
    CREDENTIALS=$( security find-generic-password -w -a ${STUDIO_USERNAME} -s studio )
  fi
fi

while [ -z "${CREDENTIALS}" ]
do
  echo -n "Studio token: "
  read -s CREDENTIALS
  echo ""
done

# Check out repository
echo ""
echo "Cloning configuration: ${PWD}/${NX_STUDIO}"
git clone ${REPO} ${NX_STUDIO}
mkdir -p ${NX_STUDIO}/conf
cp ${NX_STUDIO}/conf.d/*.conf ${NX_STUDIO}/conf
echo ""

# Write system configuration
cat << EOF > ${NX_STUDIO}/conf/system.conf
# Host Configuration
session.timeout=600
nuxeo.url=http://${FQDN}:8080/nuxeo

# Templates
nuxeo.templates=default,mongodb
EOF

# Write environment file
cat << EOF > ${NX_STUDIO}/.env
APPLICATION_NAME=${NX_STUDIO}

# Cloud Image: ${CLOUD_IMAGE}
# LTS Image  : ${LTS_IMAGE}
NUXEO_IMAGE=${FROM_IMAGE}

NUXEO_DEV=true
NUXEO_INSTALL_HOTFIX=true
NUXEO_PORT=8080
NUXEO_PACKAGES=${STUDIO_PACKAGE}

INSTALL_RPM=${INSTALL_RPM}

ELASTIC_VERSION=${ELASTIC_VERSION}
MONGO_VERSION=${MONGO_VERSION}

FQDN=${FQDN}
STUDIO_USERNAME=${STUDIO_USERNAME}
STUDIO_CREDENTIALS=${CREDENTIALS}
EOF

# Run everything in NX_STUDIO dir
cd ${NX_STUDIO}

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

# Pull / build image
echo "Please wait, getting things ready..."
make dockerfiles NUXEO_IMAGE=${FROM_IMAGE} ELASTIC_VERSION=${ELASTIC_VERSION}
docker pull --quiet ${FROM_IMAGE}
echo " building your custom image..."
docker-compose build
echo " pulling other services..."
docker-compose --log-level ERROR pull
echo ""

# Display startup instructions
make -e info
if [ -e notes.txt ]
then
  cat notes.txt
fi