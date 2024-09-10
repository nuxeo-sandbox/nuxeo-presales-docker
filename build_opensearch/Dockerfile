# ARG used by FROM should always have a default value that makes the build valid.
# https://docs.docker.com/reference/build-checks/invalid-default-arg-in-from/
ARG OPENSEARCH_IMAGE=opensearchproject/opensearch:1.3.11

FROM ${OPENSEARCH_IMAGE}

RUN bin/opensearch-plugin install analysis-kuromoji
RUN bin/opensearch-plugin install analysis-icu