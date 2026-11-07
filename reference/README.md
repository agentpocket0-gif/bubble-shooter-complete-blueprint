# reference/ — put your package here (optional)

Drop your own `.apk`, `.xapk`, `.apks` or `.zip` bundle in this folder and push, or upload it as an asset
of the `v1.0-apk` release instead (recommended for anything over ~50 MB).

The workflow looks for the package in this order:

1. the `package_url` input when you run it manually
2. the `REFERENCE_PACKAGE_URL` repository variable
3. an asset attached to the `v1.0-apk` release (draft releases are fine)
4. any `.apk` / `.xapk` / `.apks` / `.zip` file in this folder

If it finds nothing it stops with a notice instead of failing.

**Do not commit a package to a public repository.** The workflow enforces this with a visibility guard, but
by then it is already in git history — which is why the guard exists and why a private repo is step one.
