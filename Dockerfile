# ---------------------------------------------------------------
# Apps layer — thin image built on top of erpnext-crm:base-16.
#
# Adds every app listed in apps-custom.json without touching the
# heavy base build (ERPNext, CRM, Helpdesk, Builder).
#
# Build time:  ~1-2 minutes  (vs 20+ min for the base image)
# Rebuilds:    when apps-custom.json changes OR an app gets new commits
# Tag:         ghcr.io/steven-baron/erpnext-crm:16
# ---------------------------------------------------------------
FROM ghcr.io/steven-baron/erpnext-crm:base-16

USER frappe
WORKDIR /home/frappe/frappe-bench

COPY --chown=frappe:frappe scripts/install-apps.py /tmp/install-apps.py
COPY --chown=frappe:frappe apps-custom.json        /tmp/apps-custom.json

# APPS_SHA is set by CI to the combined SHA of all custom-app branches.
# Changing it busts this layer's cache, forcing apps to be re-cloned.
ARG APPS_SHA=""
RUN : "${APPS_SHA}" && python3 /tmp/install-apps.py /tmp/apps-custom.json
