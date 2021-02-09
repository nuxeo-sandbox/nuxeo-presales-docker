#!/bin/bash

COMPOSE_DIR=${COMPOSE_DIR:-${1:-.}}
NUXEO_ENV="${COMPOSE_DIR}/.env"

DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
LTS_IMAGE="${DOCKER_PRIVATE}/nuxeo/nuxeo:"
CLOUD_IMAGE="docker.packages.nuxeo.com/nuxeo/nuxeo:"

FROM_IMAGE=$(grep '^NUXEO_IMAGE' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
FQDN=$(grep '^FQDN' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
STUDIO_USERNAME=$(grep '^STUDIO_USERNAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
APPLICATION_NAME=$(grep '^APPLICATION_NAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
NUXEO_PORT=$(grep '^NUXEO_PORT' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)

if [[ -e ${COMPOSE_DIR}/conf/system.conf ]]
then
  URL=$(grep '^nuxeo.url' ${COMPOSE_DIR}/conf/system.conf | tail -n 1 | cut -d '=' -f2)
fi

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

cat << EOM

Nuxeo Installation

 Image: ${FROM_IMAGE} (Image type: ${IMAGE_DESC})
 Host:  ${FQDN}
 Port:  ${NUXEO_PORT}
 URL:   ${URL:-none set}

Studio
 User:    ${STUDIO_USERNAME}
 Project: ${APPLICATION_NAME}
 Link:    https://connect.nuxeo.com/nuxeo/site/studio/ide?project=${APPLICATION_NAME}

EOM
