#!/bin/bash
#
# ArgBash Template: https://argbash.io/send_template#generated
#
# ARG_OPTIONAL_SINGLE([dir], [d], [Creation directory, defaults to current working directory], [${PWD}])
# ARG_OPTIONAL_SINGLE([application], [a], [Application (Studio) project name], [${APPLICATION_NAME}])

# ARG_OPTIONAL_SINGLE([user], [u], [Studio username], [${USER}])
# ARG_OPTIONAL_SINGLE([pass], [p], [Studio password, will be read from command line if not provided])

# ARG_OPTIONAL_SINGLE([version], [v], [Nuxeo version (from Docker Hub)], [latest])
# ARG_OPTIONAL_SINGLE([host], [o], [Specify Nuxeo hostname], [localhost])
# ARG_OPTIONAL_SINGLE([port], [l], [Listen on specified port], [8080])
# ARG_OPTIONAL_REPEATED([template], [t], [Add configuration template], [])

# ARG_OPTIONAL_SINGLE([mp-opts], [m], [Nuxeo Marketplace Install options], [--relax=false])

# ARG_OPTIONAL_SINGLE([nxuser], , [(Advanced) Nuxeo runtime user], [nuxeo])
# ARG_OPTIONAL_BOOLEAN([nxhotfix], , [(Advanced) Apply HotFix packages'], [on])
# ARG_OPTIONAL_SINGLE([nxdata], , [(Advanced) Nuxeo data directory], [/var/lib/nuxeo/data])
# ARG_OPTIONAL_SINGLE([nxlog], , [(Advanced) Nuxeo log directory], [/var/log/nuxeo])

# ARG_OPTIONAL_BOOLEAN([verbose], , [Verbose output])

# ARG_POSITIONAL_INF([packages], [Packages to include, in addition to application-name])

# ARG_HELP([Nuxeo Docker Environment Generator])
# ARGBASH_GO
