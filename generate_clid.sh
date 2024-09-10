#!/bin/bash

# Generate NUXEO_CLID and add to the .env file.

set -euf

NUXEO_ENV=".env"
ERR=""

TMP_DIR=$(mktemp -d)
mkdir -p ${TMP_DIR}
chmod 777 ${TMP_DIR}

CONF_DIR=$(readlink -f ./conf)

NUXEO_CLID=$(grep '^NUXEO_CLID' ${NUXEO_ENV} | tail -n 1  | cut -d '=' -f2)
if [ -n "${NUXEO_CLID}" ]; then
  echo "NUXEO_CLID appears to be configured in ${NUXEO_ENV} or your system environment.  Remove and then run this script again."
  exit 2
fi

FROM_IMAGE=$(grep '^NUXEO_IMAGE' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
if [ -z "${FROM_IMAGE}" ]; then
  FROM_IMAGE="docker.packages.nuxeo.com/nuxeo/nuxeo:latest"
  echo "Upstream image 'NUXEO_IMAGE' is not set in ${NUXEO_ENV}, using: ${FROM_IMAGE}"
fi

STUDIO_USERNAME=$(grep '^STUDIO_USERNAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
if [ -z "${STUDIO_USERNAME}" ]; then
  echo "'STUDIO_USERNAME' is not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi
APPLICATION_NAME=$(grep '^APPLICATION_NAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
if [ -z "${APPLICATION_NAME}" ]; then
  echo "'APPLICATION_NAME' (project name) is not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi
STUDIO_CREDENTIALS=$(grep '^STUDIO_CREDENTIALS' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
if [ -z "${STUDIO_CREDENTIALS}" ]; then
  echo "'STUDIO_CREDENTIALS' are not set, please configure ${NUXEO_ENV}"
  ERR="yes"
fi

if [ -n "${ERR}" ]; then
  rm -rf ${TMP_DIR}
  exit 1
fi

docker run --rm -v ${TMP_DIR}:/var/lib/nuxeo/:rw -v ${CONF_DIR}:/etc/nuxeo/conf.d/:ro ${FROM_IMAGE}\
       nuxeoctl register "${STUDIO_USERNAME}" "${APPLICATION_NAME}" "dev" "Docker" "${STUDIO_CREDENTIALS}"
CLID="${TMP_DIR}/instance.clid"
# Write CLID to file
if [ -f ${CLID} ]; then
  echo -n "NUXEO_CLID=" >> ${NUXEO_ENV}
  awk 1 ORS="--" ${CLID} >> ${NUXEO_ENV}
  echo "" >> ${NUXEO_ENV}
  rm -rf ${TMP_DIR}
else
  rm -rf ${TMP_DIR}
  exit 2
fi
