# Test deploy on Dokploy (isolated from production)

Validate the platform on a throwaway Dokploy project before migrating
production. Uses the `:test` image tag and its own volumes/domain so it can't
touch the live site.

## 0. Prerequisites (images on GHCR)

```bash
docker push ghcr.io/steven-baron/erpnext-crm:base-16   # clean base
docker push ghcr.io/steven-baron/erpnext-crm:test      # base + prospecting
```

`:test` is built from the clean `base-16` via:
`docker build --build-arg APPS_SHA=$(date +%s) -t ghcr.io/steven-baron/erpnext-crm:test .`

## 1. Create the Dokploy project

**Create → Compose**, name `prospecting-test`. Paste `docker-compose.yml`.

## 2. Environment variables

```env
IMAGE_NAME=ghcr.io/steven-baron/erpnext-crm
VERSION=test
SITE_NAME=test-prospecting-54-39-99-84.sslip.io
ADMIN_PASSWORD=<test password>
DB_ROOT_PASSWORD=<test password>
FRAPPE_SITE_NAME_HEADER=
DB_HOST=db

ENABLE_DB=1
CONFIGURE=1
CREATE_SITE=1
MIGRATE=0
REGENERATE_APPS_TXT=1
INSTALL_APP_ARGS=--install-app erpnext --install-app crm --install-app prospecting

# IMPORTANT: production's bench-network uses 10.89.0.0/24. A second stack on
# the same host MUST use a different subnet or Docker errors with
# "Pool overlaps with other one on this address space". Use 10.90.0 for test.
NET_PREFIX=10.90.0

TRAEFIK_NETWORK=PLACEHOLDER
```

## 3. Two-step deploy (TRAEFIK_NETWORK gotcha)

The frontend's Traefik label needs the project's auto-generated network name,
which only exists after the first deploy:

1. Deploy once with `TRAEFIK_NETWORK=PLACEHOLDER`
2. On the VPS: `docker compose ls` → copy this project's network NAME
3. Set `TRAEFIK_NETWORK` to it, **redeploy**
4. Dokploy → add domain `test-prospecting-54-39-99-84.sslip.io` → `frontend`
   service, port `8080`, HTTPS on

## 4. After the site is up — skip the setup wizard

v16's wizard fails on the USD->INR fetch and loops the desk. Skip it —
self-contained, no file needed (run in the test backend container):

```bash
cd /home/frappe/frappe-bench
SITE=test-prospecting-54-39-99-84.sslip.io
printf "%s\n" \
  "frappe.db.set_value('Installed Application', {'app_name':'frappe'}, 'is_setup_complete', 1)" \
  "frappe.db.set_value('Installed Application', {'app_name':'erpnext'}, 'is_setup_complete', 1)" \
  "frappe.db.set_default('desktop:home_page', 'workspace')" \
  "frappe.db.commit()" \
  "print('setup complete:', frappe.is_setup_complete())" \
  | bench --site $SITE console
bench --site $SITE clear-cache
```

(This sets `is_setup_complete=1` on frappe+erpnext and resets
`desktop:home_page` — v16 tracks setup in the `Installed Application` table.)

## 5. Validate

- [ ] `/app` loads the desk (redirects to `/desk` — normal v16)
- [ ] `/prospecting` loads the SPA
- [ ] `/crm` loads
- [ ] Configure Prospecting Settings API keys, run a test search
- [ ] After idle, no 504s (networking fixes working)

## 6. Set steady-state flags

Once validated, set `CONFIGURE=0 CREATE_SITE=0 REGENERATE_APPS_TXT=0` and redeploy.

## 7. Promote to production

When the test passes, tag the validated image as `:16` and migrate production
(see README "Migrating an existing site"). Production is already set up, so the
wizard step does NOT apply there.

```bash
docker tag ghcr.io/steven-baron/erpnext-crm:test ghcr.io/steven-baron/erpnext-crm:16
docker push ghcr.io/steven-baron/erpnext-crm:16
```
