#!/bin/bash

# Print a summary of the current stack orchestration

COMPOSE_DIR=${COMPOSE_DIR:-${1:-.}}
NUXEO_ENV="${COMPOSE_DIR}/.env"

FROM_IMAGE=$(grep '^NUXEO_IMAGE' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
FQDN=$(grep '^FQDN' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
STUDIO_USERNAME=$(grep '^STUDIO_USERNAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
APPLICATION_NAME=$(grep '^APPLICATION_NAME' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
NUXEO_PORT=$(grep '^NUXEO_PORT' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
NUXEO_PACKAGES=$(grep '^NUXEO_PACKAGES' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)
# TODO: need to support both.
BUILD_PACKAGES=$(grep '^BUILD_PACKAGES' ${NUXEO_ENV} | tail -n 1 | cut -d '=' -f2)

if [[ -e ${COMPOSE_DIR}/conf/system.conf ]]
then
  URL=$(grep '^nuxeo.url' ${COMPOSE_DIR}/conf/system.conf | tail -n 1 | cut -d '=' -f2)
fi

echo

echo "Nuxeo Installation"
echo "  Image: ${FROM_IMAGE}"
echo "  Host:  ${FQDN}"
echo "  Port:  ${NUXEO_PORT}"
echo "  URL:   ${URL}"
echo
echo "Studio"
echo "  User:    ${STUDIO_USERNAME}"
echo "  Project: ${APPLICATION_NAME}"
echo "  Link:    https://connect.nuxeo.com/nuxeo/site/studio/ide?project=${APPLICATION_NAME}"
echo
echo "Command line to share your configuration:"
echo
echo "INSTALL_PACKAGES=false NUXEO_PACKAGES=\"${NUXEO_PACKAGES:-}\" FQDN=${FQDN} NX_STUDIO=${NX_STUDIO} bash -c \"\$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)\""
echo