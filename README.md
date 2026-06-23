# frappe-platform

ERPNext production stack with a two-tier Docker image strategy.

## How it works

```
apps-base.json  →  build-base.yml  →  erpnext-crm:base-16   (~20 min, rarely rebuilds)
                                              ↓
apps-custom.json → build-apps.yml  →  erpnext-crm:16        (~1-2 min, rebuilds on app changes)
                                              ↓
                   docker-compose.yml  →  Dokploy
```

| Image | Contains | Rebuilds when |
|---|---|---|
| `erpnext-crm:base-16` | frappe + erpnext + CRM + Helpdesk + Builder | `apps-base.json` changes (~quarterly) |
| `erpnext-crm:16` | base + prospecting (custom apps) | any app in `apps-custom.json` gets new commits |

## Adding a custom app

1. Add it to `apps-custom.json`
2. Push to `main` — `build-apps.yml` runs automatically (~1-2 min)
3. Dokploy redeploys

## Auto-deploy when an app repo pushes

Each app repo can trigger `build-apps.yml` via `repository_dispatch`. Add this workflow to the app repo:

```yaml
on:
  push:
    branches: [develop]
jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.PLATFORM_TOKEN }}
          repository: Steven-baron/frappe-platform
          event-type: app-updated
          client-payload: '{"sha": "${{ github.sha }}"}'
```

`PLATFORM_TOKEN` = GitHub PAT with `repo` scope on this repo.

## First deploy checklist

1. Push this repo to GitHub
2. Run **build-base** workflow (Actions tab) — wait ~20 min
3. Run **build-apps** workflow — wait ~1-2 min
4. In Dokploy → Create Compose → paste `docker-compose.yml`
5. Set env vars (see `.env.example`), with `CONFIGURE=1`, `CREATE_SITE=1`
6. Deploy → watch `create-site` logs
7. Once site is up: set `CONFIGURE=0`, `CREATE_SITE=0`, redeploy
8. Complete setup — either run the wizard in the UI (configures company,
   currency, fiscal year), **or** skip it (see below)

## The setup wizard / "desk reloads forever" gotcha

Frappe v16 redirects the desk `/app → /desk` (stock behavior, not a bug).
Until setup is complete, the boot points `home_page` at `setup-wizard`, and
if the wizard's network calls fail (e.g. the USD→INR exchange-rate fetch),
the desk bounces into the failing wizard and looks like it "reloads forever".

v16 tracks setup completion per-app in the **`Installed Application`** table
(NOT System Settings). To skip the wizard on a fresh/dev site, run in the
backend container:

```bash
cat scripts/complete-setup.py | bench --site YOUR_SITE console
bench --site YOUR_SITE clear-cache
```

For production, prefer running the real wizard in the UI so company/currency
get configured.

## Migrating an existing site

If you already have a running ERPNext site on `erpnext-crm:16`:
1. Run **build-base** (new tag `base-16`, doesn't touch your running `:16`)
2. Run **build-apps** (rebuilds `:16` from new base)
3. In Dokploy: redeploy (or force-recreate backend)
4. Done — same volumes, same data, new image
