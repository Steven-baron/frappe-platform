#!/usr/bin/env python3
"""
Mark a freshly-created site's setup wizard as complete, bypassing it.

Frappe v16 tracks setup completion per-app in the `Installed Application`
table (NOT System Settings). Until frappe+erpnext are flagged complete, the
boot sets `desktop:home_page` to "setup-wizard", and the desk SPA bounces
into the wizard on every load. If the wizard's network calls fail (e.g. the
USD->INR exchange-rate fetch), the desk appears to "reload forever".

Run inside the backend container:
    bench --site <site> execute prospecting_platform.complete_setup
  OR (no app needed) pipe into console:
    cat scripts/complete-setup.py | bench --site <site> console

Use this ONLY when you want to skip the interactive wizard (dev, or a
headless deploy). For a normal production setup, just run the wizard in the
UI — it sets these flags itself.
"""
import frappe

for app in ("frappe", "erpnext"):
    if frappe.db.exists("Installed Application", {"app_name": app}):
        frappe.db.set_value("Installed Application", {"app_name": app}, "is_setup_complete", 1)

# Reset the home-page default away from "setup-wizard"
frappe.db.set_default("desktop:home_page", "workspace")
frappe.db.commit()

print("setup complete:", frappe.is_setup_complete())
print("home_page default:", frappe.db.get_default("desktop:home_page"))
