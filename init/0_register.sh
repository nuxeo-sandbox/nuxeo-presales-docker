#!/bin/sh

# Alternative way to register instance
if [ ! -e /var/lib/nuxeo/instance.clid ]; then
  echo "Registering Nuxeo instance with project ${APPLICATION_NAME}"
  nuxeoctl register ${STUDIO_USERNAME} "${APPLICATION_NAME}" "dev" "docker" "${STUDIO_CREDENTIALS}"
fi
