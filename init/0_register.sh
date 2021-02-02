#!/bin/sh

# Alternative way to register instance
if [ ! -e /var/lib/nuxeo/instance.clid ]; then
  echo "Registering Nuxeo instance with project ${APPLICATION_NAME}"
  nuxeoctl register ${STUDIO_USERNAME} "${APPLICATION_NAME}" "dev" "docker" "${STUDIO_CREDENTIALS}"
fi

# Install pending hotfixes for image
if [ ${NUXEO_INSTALL_HOTFIX:='true'} == "true" ]; then
  echo "Installing hotfixes..."
  nuxeoctl mp-hotfix --accept=true
fi

# Copy log configuration for debugging, etc.
if [ -e /docker-entrypoint-initnuxeo.d/log4j2.xml ]; then
  echo "Copying log configuration from init folder to server"
  cp -vf /docker-entrypoint-initnuxeo.d/log4j2.xml /opt/nuxeo/server/lib/log4j2.xml
elif [ -e /opt/nuxeo/server/lib/log4j2.xml ]; then
  echo "Copying server log configuration to init folder"
  cp -vf /opt/nuxeo/server/lib/log4j2.xml /docker-entrypoint-initnuxeo.d/log4j2.xml
fi
