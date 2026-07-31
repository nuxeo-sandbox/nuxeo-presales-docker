# About

> [!CAUTION]
> This branch (`with-mcp-server-and-opensearch-vector`) is **WORK IN PROGRESS**, still under implementation and test.
>
> **DO NOT USE IT** as long as this warning is displayed. (well, of course you can, and wrok on fixing issues)

Simple command line tooling for creating and managing a Docker Compose stack for running Nuxeo.

See the [Wiki](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki) for additional documentation.

> [!IMPORTANT]
> **This branch (`with-mcp-server-and-opensearch-vector`) adds two optional features:**
> **OpenSearch 3.7 + Nuxeo vector (semantic) search**, and the **Nuxeo MCP server**.
> It therefore uses **OpenSearch 3.7 + the `opensearch2` search client** (instead of
> OpenSearch 1.x + `opensearch1` on `master`), and the Nuxeo image **must be ≥ 2025.22**.
> Both features are **optional** and focused on **localhost**.
>
> ** THIS BRANCH WILL NOT WORK AT ALL WITH OUR `presales-vmdemo` and CloudFormation template**

# Compatible Versions

* Nuxeo LTS 2025 (**≥ 2025.22** required for vector search; `2025` / `2025.0` floating tags always pull the latest 2025.x)

# Requirements

* [Access to Nuxeo Docker image](https://doc.nuxeo.com/nxdoc/docker-image/#requirements)
* Docker Engine
* Docker Compose
* Git Command Line

# Usage

For running Nuxeo locally, you can install everything using the bootstrap script like so:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/nuxeo-sandbox/nuxeo-presales-docker/master/bootstrap.sh)"
```

Note: if you are testing new features, you can pass `-- -b branch-name` to the bootstrap script to clone a specific branch. To try the two optional features on this branch:

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/nuxeo-sandbox/nuxeo-presales-docker/with-mcp-server-and-opensearch-vector/bootstrap.sh)" -- -b with-mcp-server-and-opensearch-vector
```

`bootstrap.sh` now asks two extra questions:

* **Enable semantic / vector search?** (default `false`)
* **Enable Nuxeo MCP server?** (default `false`) — if yes, it also asks for the path to your local `nuxeo-mcp-server` clone and an optional branch.

See [Getting Started](https://github.com/nuxeo-sandbox/nuxeo-presales-docker/wiki/Getting-Started) for an explanation of how the script works.

For running Nuxeo elsewhere (e.g. EC2) you will need to do a bit more work to scaffold the environment. You can find an example of how to use this tooling in EC2 [here](https://github.com/nuxeo-sandbox/presales-vmdemo/blob/master/aws/ec2-scripts/setup-nuxeo.sh).

## How this branch's `bootstrap.sh` differs from `master`

For future reference, the notable changes vs the `master` bootstrap:

* **OpenSearch 3.7 + `opensearch2` client** instead of OpenSearch 1.x + `opensearch1`.
  The auto-installed search packages become `nuxeo-audit-opensearch2` and
  `nuxeo-search-client-opensearch2`, and `conf.d/core.conf` uses
  `nuxeo.opensearch2.client.server`.
* **Two extra prompts** (vector search, MCP server) that add the corresponding
  `.env` variables (`OS_HEAP`, `EMBEDDING_MODEL_*`, `NUXEO_MCP_*`).
* **The vector template is appended to `system.conf` *after* CLID generation.**
  This is the important subtlety: `generate_clid.sh` runs `nuxeoctl` against the
  **base** Nuxeo image with `./conf` mounted, and Nuxeo resolves every
  `nuxeo.append.templates.*` entry at that point. The keyword/audit templates
  (`opensearch2-audit`, `opensearch2-search-client`) ship in the `2025.22` base
  image, so they are safe to add up front. But the vector template
  (`opensearch2-vector-search-client`) only exists once the moving vector
  **package** is baked into the **custom** image — it is absent from the base
  image. If it were listed in `system.conf` during CLID generation, `nuxeoctl`
  would fail on a missing template and abort the bootstrap. So the vector
  template is added only **after** `generate_clid.sh` succeeds, via a dedicated
  `nuxeo.append.templates.vector=opensearch2-vector-search-client` line (any
  `nuxeo.append.templates.*` suffix is aggregated by Nuxeo, so this merges with
  the keyword/audit list without rewriting it). Nuxeo still gets the template at
  real startup, once the custom image (with the vector `.zip`) is built.

---

# Optional feature 1 — Semantic / vector search (OpenSearch 3.7)

The single OpenSearch 3.7 cluster hosts the keyword (BM25) "main" index + audit **and**,
when enabled, the **vector** index (k-NN + ML + neural-search). The embedding model runs
**inside OpenSearch** (CPU works, GPU only recommended for production) — no external AI service.

### What you must provide

The vector client package **`nuxeo-search-client-opensearch2-vector`** is a **moving package,
not on the marketplace yet**. Grab the latest snapshot `.zip` and drop it in
[`./nuxeo_packages/`](./nuxeo_packages/) (gitignored). The Dockerfile bakes it into the image
at build time (offline install, matched by glob — keep exactly **one** vector `.zip` there):

```
nuxeo_packages/nuxeo-search-client-opensearch2-vector-package-0.0.0-SNAPSHOT.zip
```

The other opensearch2 packages (`nuxeo-audit-opensearch2`, `nuxeo-search-client-opensearch2`)
ship inside the `nuxeo:2025.22` image and are auto-installed by `bootstrap.sh`.

### Workflow (localhost)

```bash
cd <your-stack>

# 1. Drop the vector .zip in ./nuxeo_packages/ (see above), then build Nuxeo:
docker compose build nuxeo

# 2. Start the infra and wait until healthy:
docker compose up -d mongo opensearch
docker compose ps

# 3. Register + deploy the embedding model (prints a model_id):
make register-model     # or: ./scripts/register-embedding-model.sh

# 4. Paste the printed model_id into conf/vector-search.conf:
#      nuxeo.search.client.vector.opensearch2.model.id=<the-printed-id>

# 5. (Re)build & start Nuxeo:
docker compose up -d --build nuxeo

# 6. ONE-TIME: build the vector index (otherwise Nuxeo logs "nuxeo-vector"
#    index-missing errors until it exists). Fire-and-forget, runs async.
#    Credentials are passed INLINE (default Administrator/Administrator if omitted):
NUXEO_USER=Administrator NUXEO_PWD=<admin-pwd> make reindex-vector
# or directly:
# NUXEO_USER=Administrator NUXEO_PWD=<admin-pwd> ./scripts/reindex-vector.sh

# 7. Verify both indices exist:
make check-indices      # expect "nuxeo" and "nuxeo-vector"
```

> **Credentials (inline only).** `reindex-vector` calls Nuxeo with `NUXEO_USER`/`NUXEO_PWD`,
> passed **inline** at call time (they are **not** stored in `.env`). Omit them to use the
> `Administrator/Administrator` default. Use the `VAR=val make …` **prefix** form — variables
> passed as `make … VAR=val` are not exported to the script.

> The vector reindex is also available from the **Admin Console → Elasticsearch/OpenSearch →
> Reindex** (reindex the vector index only). Re-run it only after wiping the OpenSearch volume.

Try a semantic search (reuses the standard page-provider REST API with `index=vector`):

```bash
curl -u Administrator:Administrator \
  'http://localhost:8080/nuxeo/api/v1/search/pp/default_search/execute?index=vector&pageSize=5' \
  --data-urlencode 'ecm_fulltext=how do I cancel my subscription' \
  -H 'enrichers.document: highlight' -G
```

> If you recreate the `opensearch` volume, the model is gone — re-run `make register-model`
> and update the `model.id` in `conf/vector-search.conf`.

---

# Optional feature 2 — Nuxeo MCP server

Exposes Nuxeo tools over the Model Context Protocol (HTTP transport) so an AI assistant can
query/act on Nuxeo. Runs in the **same compose stack** (profile `mcp`, off by default), reaches
Nuxeo over the internal network at `http://nuxeo:8080/nuxeo` (**Basic auth** for now; JWT later),
and is published on **`127.0.0.1:8181`** for a host-side `opencode serve`.

This branch deploys **only** the Nuxeo MCP server — **no Ollama, no Open WebUI**.

### What you must provide

The MCP image is **built from a local clone** of
[`nuxeo/nuxeo-mcp-server`](https://github.com/nuxeo/nuxeo-mcp-server) (not released yet, must be
built from a branch). Set in `.env` (bootstrap fills these when you enable MCP):

* `NUXEO_MCP_SRC` — absolute path to your local clone.
* `NUXEO_MCP_BRANCH` — branch to build (e.g. `feat-NXENG-584-semantic-search-mcp-tool` to get the
  `semantic_search` tool). Empty = build whatever is checked out. Read **only** by
  `scripts/build-nuxeo-mcp.sh` (Docker cannot check out a branch from a local build context).

The Nuxeo admin **username/password** the MCP server uses (Basic auth) are **not** stored in
`.env`; you pass them **inline** when starting the server (see below). Omit them and compose
defaults to `Administrator/Administrator`.

### Workflow (localhost)

```bash
cd <your-stack>

# Build the MCP image from the chosen branch and start it (127.0.0.1:8181).
# Credentials are passed INLINE (default Administrator/Administrator if omitted):
NUXEO_MCP_USERNAME=Administrator NUXEO_MCP_PASSWORD=<admin-pwd> make mcp-build
# or: NUXEO_MCP_USERNAME=Administrator NUXEO_MCP_PASSWORD=<admin-pwd> ./scripts/build-nuxeo-mcp.sh
curl http://127.0.0.1:8181/health

# Start an already-built image (same inline creds), stop, logs:
NUXEO_MCP_USERNAME=Administrator NUXEO_MCP_PASSWORD=<admin-pwd> make mcp-up
make mcp-down
make mcp-logs
```

> **Credentials (inline only).** The shell env overrides the compose `${…:-Administrator}`
> defaults, so pass `NUXEO_MCP_USERNAME`/`NUXEO_MCP_PASSWORD` at call time; they are **not**
> persisted in `.env` (a commented hint is left there). Use the `VAR=val make …` **prefix**
> form — variables passed as `make … VAR=val` are not exported to the recipe.

### Using it from a host-side `opencode serve`

We drive the localhost demo (questions asked from Nuxeo at `localhost:8080`) with an
`opencode` server that uses the MCP endpoint at `http://localhost:8181/mcp`:

```bash
opencode serve --hostname 127.0.0.1 --port 4096 --cors http://localhost:8080
```

> Later upgrades (password on the endpoint, exposure from the Nuxeo Web UI on AWS, JWT auth)
> are deferred. For now everything is localhost.

---

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
