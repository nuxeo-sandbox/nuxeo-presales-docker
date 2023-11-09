# Please take note of the inline directives.
# Make changes only between the specified section
# Upstream image is Rocky Linux 9

ARG NUXEO_IMAGE

# Change the source image, if necessary
FROM ${NUXEO_IMAGE}

# !!! DO NOT CHANGE BELOW THIS LINE !!!
ARG CONNECT_URL
ARG NUXEO_CLID
ARG NUXEO_PACKAGES
ARG NUXEO_HOME
ARG INSTALL_RPM

ARG NVM_VERSION=0.39.3
ARG NODE_VERSION=18.17.0

# We need to be root to run yum commands
USER 0

# Set UTF8 default locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Install FFmpeg, mediainfo and codecs
RUN dnf config-manager --set-enabled crb && dnf -y install epel-release && \
    dnf -y install https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm && \
    dnf -y install mediainfo ffmpeg x264 x265 opus flac libvpx && dnf --enablerepo=crb -y install libvorbis-devel

# Install Fonts
RUN dnf -y install google-noto-sans-cjk-jp-fonts

# Install newest version of imagemagick and icc color profiles
# RUN dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm \
#    && dnf --enablerepo=remi -y install ImageMagick7

#Install codecs for Imagemagick
RUN dnf -y install librsvg2-tools && dnf --enablerepo=devel -y install libwebp-tools

# Dependencies for GLB thumbnail generation
#RUN dnf -y install alsa-lib at-spi2-atk libX11 libXcomposite libXcursor libXdamage libXext libXi libXtst libXScrnSaver libXrandr libXrandr atk pango gtk3

# Add additional RPMs to the source image
RUN if [ -n "${INSTALL_RPM}" ]; then dnf -y install ${INSTALL_RPM}; fi


# !!! DO NOT CHANGE ABOVE THIS LINE !!!

# >>> Make your changes BELOW this line <<<

# See: https://github.com/nuxeo/nuxeo/tree/master/docker for source documentation

# Example custom package installation
# COPY --chown=900:0 /docker-entrypoint-initnuxeo.d/local-package-nodeps-*.zip ${NUXEO_HOME}/local-packages/local-package-nodeps.zip
# COPY --chown=900:0 /docker-entrypoint-initnuxeo.d/local-package-*.zip ${NUXEO_HOME}/local-packages/local-package.zip

RUN usermod -aG 998 nuxeo

# >>> Make your changes ABOVE this line <<<

# !!! DO NOT CHANGE BELOW THIS LINE (except for noted items) !!!
# Set back original (nuxeo) user
USER 900

# (Optional) Include the google credentials.
# Replace the filename with your value
# COPY google-credential.json /opt/nuxeo/google-credential.json
# ENV GOOGLE_CREDENTIALS_PATH=/opt/nuxeo/google-credential.json

# (Optional) Install node.js and tools
#RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash && \
#    source ~/.bash_profile && nvm install ${NODE_VERSION} && npm install -g @shopify/screenshot-glb obj2gltf gltf-pipeline @gltf-transform/cli

# Workaround to make the node commands available in the default system PATH used by Java
#USER 0
#RUN ln -s /home/nuxeo/.nvm/versions/node/v${NODE_VERSION}/bin/node /usr/local/bin/node
#RUN ln -s /home/nuxeo/.nvm/versions/node/v${NODE_VERSION}/bin/screenshot-glb /usr/local/bin/screenshot-glb
#RUN ln -s /home/nuxeo/.nvm/versions/node/v${NODE_VERSION}/bin/obj2gltf /usr/local/bin/obj2gltf
#RUN ln -s /home/nuxeo/.nvm/versions/node/v${NODE_VERSION}/bin/gltf-pipeline /usr/local/bin/gltf-pipeline
#RUN ln -s /home/nuxeo/.nvm/versions/node/v${NODE_VERSION}/bin/gltf-transform /usr/local/bin/gltf-transform
#USER 900

# Install packages at build time
RUN /install-packages.sh --connect-url ${CONNECT_URL} --clid ${NUXEO_CLID} ${NUXEO_PACKAGES}
# Install a local package without its dependencies (`mp-install --nodeps`)
# RUN /install-packages.sh --offline ${NUXEO_HOME}/local-packages/local-package-nodeps.zip
# Install remote packages and a local package with its dependencies
# RUN /install-packages.sh --clid ${NUXEO_CLID} nuxeo-web-ui nuxeo-drive ${NUXEO_HOME}/local-packages/local-package.zip

# !!! END OF FILE !!!
