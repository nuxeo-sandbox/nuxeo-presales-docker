# Please take note of the inline directives.
# Make changes only between the specified section
# Upstream image is CentOS 7

# Change the source image, if necessary
FROM docker.packages.nuxeo.com/nuxeo/nuxeo:latest

# !!! DO NOT CHANGE BELOW THIS LINE !!!

ARG NUXEO_CLID
ENV NUXEO_CLID $NUXEO_CLID
ARG INSTALL_RPM
ENV INSTALL_RPM $INSTALL_RPM

# We need to be root to run yum commands
USER 0
# Install RPM Fusion free repository
RUN yum -y localinstall --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm \
    && rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-el-7 \
    && yum -y install ffmpeg mediainfo x264 x265 ipa-mincho-fonts
# Add additional RPMs to the source image
RUN if [ -n "${INSTALL_RPM}" ]; then yum -y install ${INSTALL_RPM}; fi

# !!! DO NOT CHANGE ABOVE THIS LINE !!!

# >>> Make your changes below this line <<<

# See: https://github.com/nuxeo/nuxeo/tree/master/docker for source documentation

# Example custom package installation
# COPY --chown=900:0 /docker-entrypoint-initnuxeo.d/local-package-nodeps-*.zip $NUXEO_HOME/local-packages/local-package-nodeps.zip
# COPY --chown=900:0 /docker-entrypoint-initnuxeo.d/local-package-*.zip $NUXEO_HOME/local-packages/local-package.zip

# Install a local package without its dependencies (`mp-install --nodeps`)
# RUN /install-packages.sh --offline $NUXEO_HOME/local-packages/local-package-nodeps.zip
# Install remote packages and a local package with its dependencies
# RUN /install-packages.sh --clid ${NUXEO_CLID} nuxeo-web-ui nuxeo-drive $NUXEO_HOME/local-packages/local-package.zip


# >>> Make your changes above this line <<<

# !!! DO NOT CHANGE BELOW THIS LINE !!!
# Set back original (nuxeo) user
USER 900
# !!! END OF FILE !!!