#!/bin/sh

if [ ! -e /var/lib/nuxeo/data/instance.clid ]; then
  nuxeoctl register ${STUDIO_USERNAME} "${NUXEO_PROJECT}" "dev" "docker" "${STUDIO_CREDENTIALS}"
fi

if [ ${NUXEO_INSTALL_HOTFIX:='true'} == "true" ]; then
  nuxeoctl mp-hotfix --accept=true
fi

if compgen -G "*.jar" > /dev/null; then
  cp -f /docker-entrypoint-initnuxeo.d/*.jar /opt/nuxeo/server/nxserver/bundles/
fi
if compgen -G "*.xml" > /dev/null; then
  cp -f /docker-entrypoint-initnuxeo.d/*.xml /opt/nuxeo/server/nxserver/config/
fi

