# Nuxeo Presales Docker Template

Docker Compose stack for running **Nuxeo 11.x** or **LTS 2021**.

See the [Wiki](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki) for additional documentation.

## Compatible Versions

This stack is built for and compatible with **Nuxeo 2021 LTS** and **Cloud** release.

## Getting Started

If you are planning to run Nuxeo on your local laptop, use the bootstrap script:

```
bash -c "$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)"
```

This script will ask you for your Studio Project ID, Version (default is master),
and configured hostname (default is 'localhost').

Need an account or project?  Go to https://connect.nuxeo.com/

You can then choose between the Cloud (public) and LTS (private) images.  If LTS
is selected, you will need to use your Sonatype User Token credentials to log into
the repository.  Navigate to https://packages.nuxeo.com/ and use the "Sign In"
link in the upper right to log into the system.  Once logged in, access your user
token with this link: https://packages.nuxeo.com/#user/usertoken - you may create,
access existing token, or reset the token here.  Your "token name code" is your
docker username and your "token pass code" is your password.

The next set of prompts will ask for your Studio username and Studio token.
Please obtain the token from https://connect.nuxeo.com/nuxeo/site/connect/tokens

If you are on a Mac, you have the option to save your token in your keychain.  If
you choose to do so, a dialog box will pop up to verify credential access when you
use this script.

At this point, your configuration will be complete and the Nuxeo images will be
downloaded and built.  _This may consume a lot of bandwidth and may take a bit of
time_.  Please be patient.  At the end of the script, additional instructions will
be displayed.

# Support

**These features are not part of the Nuxeo Production platform.**

These solutions are provided for inspiration and we encourage customers to use them as code samples and learning resources.

This is a moving project (no API maintenance, no deprecation process, etc.) If any of these solutions are found to be useful for the Nuxeo Platform in general, they will be integrated directly into platform, not maintained here.

# License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

# About Nuxeo

Nuxeo Platform is an open source Content Services platform, written in Java. Data can be stored in both SQL & NoSQL databases.

The development of the Nuxeo Platform is mostly done by Nuxeo employees with an open development model.

The source code, documentation, roadmap, issue tracker, testing, benchmarks are all public.

Typically, Nuxeo users build different types of information management solutions for [document management](https://www.nuxeo.com/solutions/document-management/), [case management](https://www.nuxeo.com/solutions/case-management/), and [digital asset management](https://www.nuxeo.com/solutions/dam-digital-asset-management/), use cases. It uses schema-flexible metadata & content models that allows content to be repurposed to fulfill future use cases.

More information is available at [www.nuxeo.com](https://www.nuxeo.com).
