# Nuxeo Presales Docker Template

Docker Compose stack for running Nuxeo

## Getting Started

If you are planning to run Nuxeo on your local laptop, use the bootstrap script:

```
bash -c "$(curl -fsSL https://raw.github.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)"
```

This script will ask you for your Studio Project ID, Project Version (default is master), 
and configured hostname (default is 'localhost').

You can then choose between the Cloud (public) and LTS (private) images.  If LTS
is selected, you will need to use your Sonatype User Token credentials to log into
the repository.  Navigate to https://packages.nuxeo.com/ and use the "Sign In"
link in the upper right to log into the system.  Once logged in, access your user
token with this link: https://packages.nuxeo.com/#user/usertoken - you may create,
access existing token, or reset the token here.  Your "token name code" is your
docker username and your "token pass code" is your password.

The next set of prompts will ask for your Studio username and Studio token. 
Please obtain these from https://connect.nuxeo.com/

If you are on a Mac, you have  the option to save your token in your keychain.  If
you choose to do so, a dialog box will pop up to verify credential access when you
use this script.

At this point, your configuration will be complete and the Nuxeo images will be
downloaded and built.  _This may consume a lot of bandwidth and may take a bit of
time_.  Please be patient.  At the end of the script, additional instructions will
be displayed.
## Support

**These features are sand-boxed and not yet part of the Nuxeo Production platform.**

These solutions are provided for inspiration and we encourage customers to use them as code samples and learning resources.

This is a moving project (no API maintenance, no deprecation process, etc.) If any of these solutions are found to be useful for the Nuxeo Platform in general, they will be integrated directly into platform, not maintained here.

## Licensing

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)

## About Nuxeo

Nuxeo dramatically improves how content-based applications are built, managed and deployed, making customers more agile, innovative and successful. Nuxeo provides a next generation, enterprise ready platform for building traditional and cutting-edge content oriented applications. Combining a powerful application development environment with SaaS-based tools and a modular architecture, the Nuxeo Platform and Products provide clear business value to some of the most recognizable brands including Verizon, Electronic Arts, Sharp, FICO, the U.S. Navy, and Boeing. Nuxeo is headquartered in New York and Paris.

More information is available at [www.nuxeo.com](http://www.nuxeo.com).
