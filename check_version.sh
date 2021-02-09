#!/bin/bash

CHECKS=()
# Check for commands used in this script
command -v curl >/dev/null || CHECKS+=("curl")
command -v jq >/dev/null || CHECKS+=("jq")
command -v grep >/dev/null || CHECKS+=("grep")
command -v docker >/dev/null || CHECKS+=("docker")
command -v make >/dev/null || CHECKS+=("make")

if [ $CHECKS ]
then
  echo "Please install the following programs for your platform:"
  echo ${CHECKS[@]}
  exit 1
fi

COMPOSE_DIR=${COMPOSE_DIR:-${1:-.}}
NUXEO_ENV="${COMPOSE_DIR}/.env"

IMAGE_NAME="nuxeo/nuxeo"
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
LTS_IMAGE="${DOCKER_PRIVATE}/${IMAGE_NAME}:"
CLOUD_IMAGE="docker.packages.nuxeo.com/${IMAGE_NAME}:"

FROM_IMAGE=$(grep '^NUXEO_IMAGE' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)

IMAGE_DESC="Unknown"
case ${FROM_IMAGE}
in
  ${LTS_IMAGE}*)
    IMAGE_DESC="LTS"
    ;;
  ${CLOUD_IMAGE}*)
    IMAGE_DESC="Cloud"
    ;;
  *)
    IMAGE_DESC="Unknown"
    ;;
esac

SONATYPE_AUTH=""
if [[ "${IMAGE_DESC}" == "LTS" ]]
then
  echo ""
  echo "Your image is hosted in a private repository.  Please provide your Sonatype User Access Token"
  echo "  Get your token here: https://packages.nuxeo.com/#user/usertoken"
  echo ""

  # Prompt for Sonatype Login
  while [ -z "${SONATYPE_USER}" ]
  do
    echo -n "Sonatype user token name code: "
    read SONATYPE_USER
  done

  while [ -z "${SONATYPE_TOKEN}" ]
  do
    echo -n "Sonatype token pass code: "
    read -s SONATYPE_TOKEN
    echo ""
  done
  SONATYPE_AUTH="-u ${SONATYPE_USER}:${SONATYPE_TOKEN}"
fi

# Current Image SHA256
IMAGE_ID=$(docker inspect --format='{{index .RepoDigests 0}}' ${FROM_IMAGE})
IDS=(${IMAGE_ID//:/ })
TAGS=(${FROM_IMAGE//:/ })

# Search for latest with tag
LATEST=$(curl ${SONATYPE_AUTH} -fsSL -X GET "https://packages.nuxeo.com/service/rest/v1/search?name=${IMAGE_NAME}&format=docker&version=${TAGS[1]}")
REPO_SHA=$(echo ${LATEST} | jq -r '.items[].assets[].checksum.sha256')
REPO_TAG=$(echo ${LATEST} | jq -r '.items[].version')
REPO=$(echo ${LATEST} | jq -r '.items[].repository')

cat << EOM

Local Configuration
 Label: ${FROM_IMAGE}
  Type: ${IMAGE_DESC}
    ID: ${IDS[1]}
   Tag: ${TAGS[1]}

Repository Image
  Repo: ${REPO}
    ID: ${REPO_SHA}
   Tag: ${REPO_TAG}

EOM

if [[ -n "${REPO_SHA}" && "${REPO_SHA}a" != "${IDS[1]}" ]]
then
  echo -n "It appears there is a newer image available.  Pull image and rebuild? y/n [y]: "
  read UPDATE

  if [[ -z "${UPDATE}" || "${UPDATE}" == "y" || "${UPDATE}" == "Y" ]]
  then
    make rebuild
  fi
fi