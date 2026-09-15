#!/bin/sh

# Presales log4j customizations:
#
# Preface: this isn't generic tooling. These are intentional log4j
# customizations that the presales team needs. Some may be temporary. I.e. it's
# not meant to allow you to drop in random log4j changes. Use the existing
# examples workflow for that. This is for things we want to bake in in all
# cases.
#
#   1. Suppress the Web UI `user does not exist` 404 WARN noise for the `system`
#      user (regression WEBUI-1096 / ELEMENTS-1995, tracked by WEBUI-2309).
#   2. Reset server.log on JVM start so `nx logs` shows only the current
#      session. Meanwhile, old logs are archived so nothing is lost except that
#      we only keep the newest 50 archives.
#
# Usage: don't run this, it's used by Docker

set -e

# Refuse to run unless invoked by the image build (see build_nuxeo/Dockerfile),
# which sets this sentinel. Stops accidental runs against a live log4j2.xml.
if [ "${PRESALES_LOG4J_BUILD}" != "1" ]; then
  echo "apply-presales-log4j: build-time only; run via the Docker build" >&2
  exit 1
fi

OOTB_LOG4J="${1:-/opt/nuxeo/server/lib/log4j2.xml}"

if [ ! -f "${OOTB_LOG4J}" ]; then
  echo "apply-presales-log4j: ${OOTB_LOG4J} not found, nothing to do"
  exit 0
fi

# Note: each fragment is stored in a temporary file; this is the safest way to
# inject the XML blocks (e.g. instead of strings in vars).

#   1. Suppress the Web UI `user does not exist` 404 WARN noise for the `system`
#      user (regression WEBUI-1096 / ELEMENTS-1995, tracked by WEBUI-2309).
hide_system_user_logger="$(mktemp)"
cat > "${hide_system_user_logger}" << 'EOF'
    <!-- Suppress the Web UI `user does not exist` 404 WARN noise
         for the `system` user (WEBUI-1096 / ELEMENTS-1995, tracked by WEBUI-2309). -->
    <Logger name="org.nuxeo.ecm.webengine.app.WebEngineExceptionMapper" level="warn">
      <ThreadContextMapFilter onMatch="DENY" onMismatch="NEUTRAL" operator="and">
        <KeyValuePair key="PathInfo" value="/api/v1/user/system" />
      </ThreadContextMapFilter>
    </Logger>
EOF

#   2. Reset server.log on JVM start so `nx logs` shows only the current
#      session. Meanwhile, old logs are archived so nothing is lost except that
#      we only keep the newest 50 archives.
reset_server_log_appender="$(mktemp)"
cat > "${reset_server_log_appender}" << 'EOF'
    <!-- Reset server.log on JVM start so `nx logs` shows only the current
         session. Old logs are archived (newest 50 kept) so nothing is lost.
         Replaces the default FILE-ORIGINAL appender. -->
    <RollingFile name="FILE-ORIGINAL" fileName="${sys:nuxeo.log.dir}/server.log"
                 filePattern="${sys:nuxeo.log.dir}/server-%d{yyyy-MM-dd}-%i.log.gz">
      <PatternLayout pattern="${fileLayout}" />
      <Policies>
        <OnStartupTriggeringPolicy /> <!-- archive the previous session on every JVM start -->
        <TimeBasedTriggeringPolicy /> <!-- daily rollover at midnight (from %d in filePattern) -->
      </Policies>
      <DefaultRolloverStrategy>
        <Delete basePath="${sys:nuxeo.log.dir}" maxDepth="1">
          <IfFileName glob="server-*.log.gz" />
          <IfAccumulatedFileCount exceeds="50" /> <!-- keep newest 50 archives, prune oldest -->
        </Delete>
      </DefaultRolloverStrategy>
    </RollingFile>
EOF

spliced_log4j="$(mktemp)"

# This finds two specific lines in the default log4j2.xml -- the FILE-ORIGINAL
# appender (which we replace) and the <Loggers> tag (we add our logger right
# after it). If a future Nuxeo release renames or removes those lines, that
# change is simply skipped and the rest of the file is left untouched.
awk -v logger_file="${hide_system_user_logger}" -v appender_file="${reset_server_log_appender}" '
  function emit(f,   line) { while ((getline line < f) > 0) print line; close(f) }
  # Replace the default FILE-ORIGINAL appender with the presales rolling config.
  /<RollingFile name="FILE-ORIGINAL"/ { emit(appender_file); skip = 1; next }
  skip && /<\/RollingFile>/           { skip = 0; next }
  skip                                { next }
  # Insert the hide-system-user logger just inside <Loggers>.
  /<Loggers>/                         { print; emit(logger_file); next }
  { print }
' "${OOTB_LOG4J}" > "${spliced_log4j}"

# Overwrite the file's contents (rather than moving the temp file over it) so
# it keeps its original owner and permissions.
cat "${spliced_log4j}" > "${OOTB_LOG4J}"
# Clean up temporary files used for splicing the log4j2.xml.
rm -f "${spliced_log4j}" "${hide_system_user_logger}" "${reset_server_log_appender}"

echo "apply-presales-log4j: customizations applied to ${OOTB_LOG4J}"
