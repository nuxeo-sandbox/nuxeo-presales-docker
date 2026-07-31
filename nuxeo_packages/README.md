# Local Nuxeo packages (baked at build time)

Drop local Nuxeo package `.zip` files here to have them installed **offline**
into the custom Nuxeo image at build time (see `build_nuxeo/Dockerfile`).

## Vector / semantic search

The semantic (vector) search feature needs the **moving** package
`nuxeo-search-client-opensearch2-vector`, which is **not on the marketplace yet**.
Grab the latest snapshot and drop it here, e.g.:

```
nuxeo_packages/nuxeo-search-client-opensearch2-vector-package-0.0.0-SNAPSHOT.zip
```

Then (re)build Nuxeo:

```
docker compose up -d --build nuxeo
```

Notes:
- Keep exactly **one** vector `.zip` here (the Dockerfile installs by glob).
- The other opensearch2 packages (`nuxeo-audit-opensearch2`,
  `nuxeo-search-client-opensearch2`) ship inside the `nuxeo:2025.22` image and
  are activated via Connect packages / templates — no `.zip` needed for those.
- The `.zip` files are gitignored; this folder and this README are kept so the
  Docker build context always has the directory.
