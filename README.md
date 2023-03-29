# About

Simple command line tooling for creating and managing a Docker Compose stack for
running Nuxeo.

See the [Wiki](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki) for
additional documentation.

# Compatible Versions

* Nuxeo LTS 2021

# Requirements

* [Access to Nuxeo Docker image](https://doc.nuxeo.com/nxdoc/docker-image/#requirements)
* Docker Engine
* Docker Compose
* Git Command Line

# Usage

For running Nuxeo locally, you can install everything using the bootstrap script
like so:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)"
```

See [Getting
Started](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki/Getting-Started)
for an explanation of how the script works.

For running Nuxeo elsewhere (e.g. EC2) you will need to do a bit more work to
scaffold the environment. You can find an example of how to use this tooling in
EC2
[here](https://github.com/nuxeo/presales-vmdemo/blob/master/AWS-templates/Nuxeo_Release_presales).

# Support

**These features are not part of the Nuxeo Production platform.**

These solutions are provided for inspiration and we encourage customers to use
them as code samples and learning resources.

This is a moving project (no API maintenance, no deprecation process, etc.) If
any of these solutions are found to be useful for the Nuxeo Platform in general,
they will be integrated directly into platform, not maintained here.

# License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

# About Nuxeo

Nuxeo Platform is an open source Content Services platform, written in Java.
Data can be stored in both SQL & NoSQL databases.

The development of the Nuxeo Platform is mostly done by Nuxeo employees with an
open development model.

The source code, documentation, roadmap, issue tracker, testing, benchmarks are
all public.

Typically, Nuxeo users build different types of information management solutions
for [document management](https://www.nuxeo.com/solutions/document-management/),
[case management](https://www.nuxeo.com/solutions/case-management/), and
[digital asset
management](https://www.nuxeo.com/solutions/dam-digital-asset-management/), use
cases. It uses schema-flexible metadata & content models that allows content to
be repurposed to fulfill future use cases.

More information is available at [www.nuxeo.com](https://www.nuxeo.com).
