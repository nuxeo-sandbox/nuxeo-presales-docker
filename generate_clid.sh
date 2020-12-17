#!/bin/bash

# Manually generate and add NUXEO_CLID to the .env file for use when building images or 
# starting the Nuxeo runtime.  Use with caution, as the automated install may have already
# set the NUXEO_CLID value.

set -euf

NUXEO_ENV=".env"
ERR=""

TMP_DIR="/tmp/nuxeo"

NUXEO_CLID=$(grep NUXEO_CLID ${NUXEO_ENV} | cut -d '=' -f2)
if [ -n "${NUXEO_CLID}" ]; then
  echo "NUXEO_CLID appears to be configure in ${NUXEO_ENV} or your system environment.  Remove and then run this script again."
  exit 2
fi

FROM_IMAGE=$(grep FROM_IMAGE ${NUXEO_ENV} | cut -d '=' -f2)
if [ -z "${FROM_IMAGE}" ]; then
  FROM_IMAGE="docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
  echo "Upstream image 'FROM_IMAGE' is not set in ${NUXEO_ENV}, using: ${FROM_IMAGE}"
fi

STUDIO_USERNAME=$(grep STUDIO_USERNAME ${NUXEO_ENV} | cut -d '=' -f2)
if [ -z "${STUDIO_USERNAME}" ]; then
  echo "'STUDIO_USERNAME' is not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi
APPLICATION_NAME=$(grep APPLICATION_NAME ${NUXEO_ENV} | cut -d '=' -f2)
if [ -z "${APPLICATION_NAME}" ]; then
  echo "'APPLICATION_NAME' (project name) is not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi
STUDIO_CREDENTIALS=$(grep STUDIO_CREDENTIALS ${NUXEO_ENV} | cut -d '=' -f2)
if [ -z "${STUDIO_CREDENTIALS}" ]; then
  echo "'STUDIO_CREDENTIALS' are not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi

if [ -n "${ERR}" ]; then
  exit 1
fi

docker run -it -v ${TMP_DIR}:/var/lib/nuxeo/:rw ${FROM_IMAGE} \
       nuxeoctl register "${STUDIO_USERNAME}" "${APPLICATION_NAME}" "dev" "Docker" "${STUDIO_CREDENTIALS}"
if [ -e ${TMP_DIR}/instance.clid ]; then
  echo -n "NUXEO_CLID=" >> ${NUXEO_ENV}
  awk 1 ORS="--" ${TMP_DIR}/instance.clid >> ${NUXEO_ENV}
  echo "" >> ${NUXEO_ENV}
fi