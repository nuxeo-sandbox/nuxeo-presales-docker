#!/bin/sh

# Presales log4j customizations:
#
# Preface: this isn't generic tooling. These are intentional log4j
# customizations that the presales team needs. Some may be temporary. I.e. it's
# not meant to allow you to drop in random log4j changes. Use the existing
# examples workflow for that. This is for things we want to bake in in all
# cases.
#
#   1. Reset server.log on JVM start so `nx logs` shows only the current
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

#   1. Reset server.log on JVM start so `nx logs` shows only the current
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

# This finds one specific line in the default log4j2.xml -- the FILE-ORIGINAL
# appender (which we replace). If a future Nuxeo release renames or removes that
# line, the change is simply skipped and the rest of the file is left untouched.
awk -v appender_file="${reset_server_log_appender}" '
  function emit(f,   line) { while ((getline line < f) > 0) print line; close(f) }
  # Replace the default FILE-ORIGINAL appender with the presales rolling config.
  /<RollingFile name="FILE-ORIGINAL"/ { emit(appender_file); skip = 1; next }
  skip && /<\/RollingFile>/           { skip = 0; next }
  skip                                { next }
  { print }
' "${OOTB_LOG4J}" > "${spliced_log4j}"

# Overwrite the file's contents (rather than moving the temp file over it) so
# it keeps its original owner and permissions.
cat "${spliced_log4j}" > "${OOTB_LOG4J}"
# Clean up temporary files used for splicing the log4j2.xml.
rm -f "${spliced_log4j}" "${reset_server_log_appender}"

echo "apply-presales-log4j: customizations applied to ${OOTB_LOG4J}"
