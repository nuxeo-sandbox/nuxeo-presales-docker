#!/bin/sh

if [ ! -e /var/lib/nuxeo/instance.clid ]; then
  echo "Registering Nuxeo instance with project ${APPLICATION_NAME}"
  nuxeoctl register ${STUDIO_USERNAME} "${APPLICATION_NAME}" "dev" "docker" "${STUDIO_CREDENTIALS}"
fi

if [ ${NUXEO_INSTALL_HOTFIX:='true'} == "true" ]; then
  echo "Installing hotfixes..."
  nuxeoctl mp-hotfix --accept=true
fi

if [ -n "${ADDITIONAL_PACKAGES}" ]; then
  echo "Installing additional packages..."
  nuxeoctl mp-install --accept=true ${ADDITIONAL_PACKAGES}
fi
