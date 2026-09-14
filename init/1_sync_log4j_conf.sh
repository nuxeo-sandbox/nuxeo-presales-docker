#!/bin/sh

# Sync the log4j2 configuration between the host `init` folder and the server.
#
# - If a log4j2.xml is provided in the `init` folder, copy it INTO the server so
#   custom logging (debug, etc.) takes effect.
# - Otherwise, copy the server's default log4j2.xml OUT to the `init` folder so it
#   can be used as a starting point for customization.

if [ -e /docker-entrypoint-initnuxeo.d/log4j2.xml ]; then
  echo "Copying log configuration from init folder to server"
  cp -vf /docker-entrypoint-initnuxeo.d/log4j2.xml /opt/nuxeo/server/lib/log4j2.xml || echo "Unable to copy user log configuration"
elif [ -e /opt/nuxeo/server/lib/log4j2.xml ]; then
  echo "Copying server log configuration to init folder"
  cp -vf /opt/nuxeo/server/lib/log4j2.xml /docker-entrypoint-initnuxeo.d/log4j2.xml || echo "Unable to copy server log configuration"
fi
