#!/bin/bash

REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
LTS_IMAGE="${DOCKER_PRIVATE}/nuxeo/nuxeo:2021.x"
CLOUD_IMAGE="docker.packages.nuxeo.com/nuxeo/nuxeo:latest"

MONGO_VERSION="4.4"
ELASTIC_VERSION="7.9.3"

CHECKS=()
# Check for commands used in this script
command -v make >/dev/null || CHECKS+=("make")
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")

if [ $CHECKS ]
then
  echo "Please install the following programs:"
  echo ${CHECKS[@]}
  exit 1
fi

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
echo "Which image?"
select lc in "LTS" "Cloud"
do
    if [[ "$lc" == "LTS" || "$lc" == "1" ]]
    then
        echo "LTS selected"
        FROM_IMAGE=${LTS_IMAGE}
        break
    elif [[ "$lc" == "Cloud" || "$lc" == "2" ]]
    then
        echo "Cloud selected"
        FROM_IMAGE=${CLOUD_IMAGE}
        break
    fi
done

export FROM_IMAGE
echo ""
echo "Using Image: ${FROM_IMAGE}"

# Check out repository
echo ""
echo "Cloning docker configuration: ${PWD}/${NX_STUDIO}"
git clone ${REPO} ${NX_STUDIO}
mkdir -p ${NX_STUDIO}/conf
cp ${NX_STUDIO}/conf.d/*.conf ${NX_STUDIO}/conf
echo ""

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

# Prompt for Studio Login
while [ -z "${STUDIO_USERNAME}" ]
do
  echo -n "Studio username: "
  read STUDIO_USERNAME
done
while [ -z "${CREDENTIALS}" ]
do
  echo -n "Studio token: "
  read -s CREDENTIALS
  echo ""
done

# Write system configuration
cat << EOF > ${NX_STUDIO}/conf/system.conf
# Host Configuration
session.timeout=600
nuxeo.url=http://${FQDN}:8080/nuxeo
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