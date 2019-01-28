# Nuxeo Presales Docker Template

Shell script to generate a working docker-compose installation with sync.

## Dependencies

Install [docker-sync.io](http://docker-sync.io/) to enable fast content synchronization within the container.

## Execution

```bash
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
	--nxhotfix,--no-nxhotfix: (Advanced) Apply HotFix packages (false by default)
	--nxdata: (Advanced) Nuxeo data directory (default: '/var/lib/nuxeo/data')
	--nxlog: (Advanced) Nuxeo log directory (default: '/var/log/nuxeo')
	--verbose,--no-verbose: Verbose output (off by default)
	-h,--help: Prints help
```

### Example

```bash
nuxeo-project$ ~/scripts/create.sh -t mongodb -v 10.3 nuxeo-web-ui nuxeo-jsf-ui nuxeo-platform-3d
```

Install the `nuxeo-project` application with the `mongodb` template for 10.3.  Will add the Web UI, JSF, and 3D packages.

### With `nuxeo sync`

Use the Nuxeo command line tool to synchronize directories with the container.  If you're working on a package called 'nuxeo-plugin', you can automatically synchronize your Web UI changes.

Example:

```bash
nuxeo-project$ nuxeo sync --src ~/dev/nuxeo-plugin/nuxeo-plugin-web-ui/src/main/resources/web/nuxeo.war/ui --dest $PWD/nuxeo.war/
```

## macOS Tips and Tricks

### Use nuxeo-platform-3d with Nuxeo Docker

Use `socat/docker-compose.yml` to set up a Docker services bridge for macOS.  Modify your application's docker-compose.yml to expose the correct `DOCKER_HOST` and binary volume.  Nuxeo will now be able to launch other containers on your system

### Local Hostname

Define a local loopback alias and hostname for your machine.  This will allow you to provide an alias for your localhost address (127.0.0.1) within containers.  Remember, each container will have it's own 127.0.0.1 adapter.  Leveraging the localhost alias will allow you to seamlessly talk between one or more containers.

Create the following XML within `/Library/LaunchDaemons/com.startup.alias.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.startup.alias</string>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>ProgramArguments</key>
    <array>
	    <string>ifconfig</string>
        <string>lo0</string>
        <string>alias</string>
        <string>172.16.123.1</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Enable it:

```bash
# Add it to your running machine
sudo ifconfig lo0 alias 172.16.123.1
# Add it to your startup instructions
sudo launchctl load $PWD/com.startup.alias.plist
```

Then add an entry to your `/etc/hosts`:

`172.16.123.1  myhost`

You'll now be able to use 'myhost' in your address bar to access your local resources: http://myhost:8080

## Support

**These features are sand-boxed and not yet part of the Nuxeo Production platform.**

These solutions are provided for inspiration and we encourage customers to use them as code samples and learning resources.

This is a moving project (no API maintenance, no deprecation process, etc.) If any of these solutions are found to be useful for the Nuxeo Platform in general, they will be integrated directly into platform, not maintained here.

## Licensing

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)

## About Nuxeo

Nuxeo dramatically improves how content-based applications are built, managed and deployed, making customers more agile, innovative and successful. Nuxeo provides a next generation, enterprise ready platform for building traditional and cutting-edge content oriented applications. Combining a powerful application development environment with SaaS-based tools and a modular architecture, the Nuxeo Platform and Products provide clear business value to some of the most recognizable brands including Verizon, Electronic Arts, Sharp, FICO, the U.S. Navy, and Boeing. Nuxeo is headquartered in New York and Paris.

More information is available at [www.nuxeo.com](http://www.nuxeo.com).

