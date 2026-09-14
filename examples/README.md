# Examples

Optional configuration samples. Types of items you'll find in this folder:

* `nuxeo.conf` fragments: Copy the file into your the `conf` directory,
  uncomment the settings you want if needed.
* `log4j2` logging changes: customizations to the platform's `log4j2.xml`. Copy
  the snippet into `init/log4j2.xml`.

Examples may be self-contained (e.g. embedded comments explain the usage) or
documented on the
[wiki](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki).

## About log4j changes

Nuxeo Presales Docker (NPD) manages the synchronization of `log4j2.xml` between
the `init` folder and the container. Run Nuxeo at least once to get a copy of
the live `log4j2.xml` from the container. Then you can make changes to
`init/log4j2.xml` and have them applied to the container on the next startup.
