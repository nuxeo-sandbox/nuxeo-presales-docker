#!/bin/sh

# Shortcut to create a new stack
alias nxcreate='bash -c "$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)"'

# Example aliases for working with docker-compose and Nuxeo
alias dcb='docker-compose build'
alias dcdn='docker-compose down'
alias dce='docker-compose exec'
alias dck='docker-compose kill'
alias dcl='docker-compose logs'
alias dclf='docker-compose logs -f'
alias dco=docker-compose
alias dcps='docker-compose ps'
alias dcpull='docker-compose pull'
alias dcr='docker-compose run'
alias dcrestart='docker-compose restart'
alias dcrm='docker-compose rm'
alias dcstart='docker-compose start'
alias dcstop='docker-compose stop'
alias dcup='docker-compose up'
alias dcupd='docker-compose up -d'

# QOL aliases to make managing the stack easier
alias stack='make -e'
alias nx='stack SERVICE=nuxeo'
# See https://github.com/nuxeo-sandbox/nuxeo-presales-docker/issues/10
alias nxlogs='nx logs'
alias nxl='nx exec COMMAND="tail -f /var/log/nuxeo/server.log"'
alias nxbash='nx exec COMMAND=bash'
alias es='stack SERVICE=elasticsearch'
alias mongodb='stack SERVICE=mongo'
alias mongo='stack exec SERVICE=mongo COMMAND=mongo'
# This is a hard-coded hack for now; the root problem is `nx pull` does nothing
# useful because we're using a custom image. What we want to do is pull the
# latest base nuxeo image, and then build a new local image.
alias nxpull='docker pull docker-private.packages.nuxeo.com/nuxeo/nuxeo:2021'

# Quick access to nuxeoctl
alias nxctl-status='nx exec COMMAND="nuxeoctl status"'
alias nxctl-stop='nx exec COMMAND="nuxeoctl stop"'
alias nxctl-start='nx exec COMMAND="nuxeoctl start"'
alias nxctl-restart='nx exec COMMAND="nuxeoctl restart"'
alias nxctl-mp-list='nx exec COMMAND="nuxeoctl mp-list"'
alias nxctl-showconf='nx exec COMMAND="nuxeoctl showconf"'
alias nxctl-tail='nx exec COMMAND="tail -f /var/log/nuxeo/server.log"'
