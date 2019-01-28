# Nuxeo Presales Docker Template

Shell script to generate a working docker-compose installation with sync.

## Dependencies

Install [docker-sync.io](http://docker-sync.io/) to enable fast content synchronization within the container.

## Execution

```
Nuxeo Docker Environment Generator
Usage: ./create.sh [-d|--dir <arg>] [-a|--application <arg>] [-u|--user <arg>] [-p|--pass <arg>] [-v|--version <arg>] [-o|--host <arg>] [-l|--port <arg>] [-t|--template <arg>] [-m|--mp-opts <arg>] [--nxuser <arg>] [--(no-)nxhotfix] [--nxdata <arg>] [--nxlog <arg>] [--(no-)verbose] [-h|--help] [<packages-1>] ... [<packages-n>] ...
	<packages>: Packages to include, in addition to application-name
	-d,--dir: Creation directory, defaults to current working directory (default: '${PWD}')
	-a,--application: Application (Studio) project name (default: '$(basename ${PWD})')
	-u,--user: Studio username (default: '${USER}')
	-p,--pass: Studio password, will be read from command line if not provided (no default)
	-v,--version: Nuxeo version (from Docker Hub) (default: 'latest')
	-o,--host: Specify Nuxeo hostname (default: 'localhost')
	-l,--port: Listen on specified port (default: '9090')
	-t,--template: Add configuration template (empty by default)
	-m,--mp-opts: Nuxeo Marketplace Install options (default: '--relax=false')
	--nxuser: (Advanced) Nuxeo runtime user (default: 'nuxeo')
	--nxhotfix,--no-nxhotfix: (Advanced) Apply HotFix packages' (false by default)
	--nxdata: (Advanced) Nuxeo data directory (default: '/var/lib/nuxeo/data')
	--nxlog: (Advanced) Nuxeo log directory (default: '/var/log/nuxeo')
	--verbose,--no-verbose: Verbose output (off by default)
	-h,--help: Prints help
```

### Example

```
nuxeo-project$ ~/scripts/create.sh -t mongodb -v 10.3 nuxeo-web-ui nuxeo-jsf-ui nuxeo-platform-3d
```

Install the `nuxeo-project` application with the `mongodb` template for 10.3.  Will add the Web UI, JSF, and 3D packages.

### With `nuxeo sync`

Use the Nuxeo command line tool to synchronize directories with the container.  If you're working on a package called 'nuxeo-plugin', you can automatically synchronize your Web UI changes.

Example:

```
nuxeo-project$ nuxeo sync --src ~/dev/nuxeo-plugin/nuxeo-plugin-web-ui/src/main/resources/web/nuxeo.war/ui --dest $PWD/nuxeo.war/
```

## Support

**These features are sand-boxed and not yet part of the Nuxeo Production platform.**

These solutions are provided for inspiration and we encourage customers to use them as code samples and learning resources.

This is a moving project (no API maintenance, no deprecation process, etc.) If any of these solutions are found to be useful for the Nuxeo Platform in general, they will be integrated directly into platform, not maintained here.

## Licensing

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)

## About Nuxeo

Nuxeo dramatically improves how content-based applications are built, managed and deployed, making customers more agile, innovative and successful. Nuxeo provides a next generation, enterprise ready platform for building traditional and cutting-edge content oriented applications. Combining a powerful application development environment with SaaS-based tools and a modular architecture, the Nuxeo Platform and Products provide clear business value to some of the most recognizable brands including Verizon, Electronic Arts, Sharp, FICO, the U.S. Navy, and Boeing. Nuxeo is headquartered in New York and Paris.

More information is available at [www.nuxeo.com](http://www.nuxeo.com).

