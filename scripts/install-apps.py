#!/usr/bin/env python3
"""
Install custom Frappe apps as a thin layer on top of the base image.

For each app in the JSON file:
  - git clone into apps/
  - register the Python module (.pth file)
  - add to apps.txt
  - symlink public/ into assets/ (persists because assets/ is not a VOLUME)
"""
import json, subprocess, os, sys


def install(apps_json_path: str) -> None:
    bench = "/home/frappe/frappe-bench"
    os.chdir(bench)
    pyver = next(p for p in os.listdir("env/lib") if p.startswith("python3."))

    apps = json.load(open(apps_json_path))
    for app in apps:
        url = app["url"].rstrip("/")
        branch = app.get("branch", "main")
        name = url.split("/")[-1]
        print(f"\n=== {name}  branch={branch} ===")

        # Remove existing dir (base image may already have an older version)
        if os.path.isdir(f"apps/{name}"):
            import shutil
            shutil.rmtree(f"apps/{name}")

        subprocess.run(
            ["git", "clone", "--depth", "1", "-b", branch, url, f"apps/{name}"],
            check=True,
        )

        # Python module registration
        pth = f"env/lib/{pyver}/site-packages/{name}.pth"
        open(pth, "w").write(f"{bench}/apps/{name}\n")
        print(f"  .pth → {pth}")

        # apps.txt (create if missing)
        try:
            lines = open("apps.txt").read().splitlines()
        except FileNotFoundError:
            lines = []
        if name not in lines:
            open("apps.txt", "a").write(f"{name}\n")
            print(f"  added to apps.txt")

        # Asset symlink
        # assets/ lives at the bench root and is NOT a Docker VOLUME, so
        # symlinks created here persist in the image layer.
        pub = f"{bench}/apps/{name}/{name}/public"
        dst = f"assets/{name}"
        if os.path.isdir(pub):
            if os.path.lexists(dst):
                os.remove(dst)
            os.symlink(pub, dst)
            print(f"  assets/{name} → …/{name}/public/")
        else:
            print(f"  no public/ dir — skipping asset link")

    print("\n✓ All apps installed.")


if __name__ == "__main__":
    install(sys.argv[1] if len(sys.argv) > 1 else "/tmp/apps-custom.json")
