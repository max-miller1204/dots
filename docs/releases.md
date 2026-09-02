# Releases

The root `version` file is the release version source of truth. Releases use
stable semantic versions (`X.Y.Z`) and matching Git tags (`vX.Y.Z`). Update and
commit `version` before creating the tag; the release build fails if they do not
match. Publish fixes as a new version rather than replacing an existing release.

Pushing a version tag runs the GitHub release workflow. It builds and
smoke-tests `dots-X.Y.Z.tar.gz`, then publishes that archive, `install.sh`,
`SHA256SUMS`, and the updater-readable `dots-release.txt` manifest on the
GitHub release. The generated installer pins that release's archive name and
SHA-256; it downloads and verifies the artifact before delegating to the
packaged transactional installer. The archive contains only the versioned
runtime payload:
`bin`, `config`, `default`, `install`, `migrations`, `themes`, and `version`,
under a `dots-X.Y.Z` directory.

To build the same files locally from the current commit:

```bash
./scripts/build-release.sh vX.Y.Z
```

Pass a second argument to choose an output directory. The build always reads
committed `HEAD`, so uncommitted files cannot leak into a release. Verify downloaded
assets with `sha256sum -c SHA256SUMS` on Linux or
`shasum -a 256 -c SHA256SUMS` on macOS.

## Installed releases

Stable releases are unpacked into `~/.local/share/dots/releases/<version>`.
Owned `current` and `previous` symlinks provide runtime rollback. Their
activation and recovery protocol is described in
[`docs/update-process.md`](update-process.md#activation-and-rollback). The
editable checkout is independent and may remain dirty while stable
`dots update` installs releases.

Normal installations run the latest release's `install.sh` directly and do not
require a Git checkout. Use `dots version install`, `dots version list`, and
`dots version rollback` to manage bundles afterward. `dots version list` verifies each candidate's ownership marker
and complete integrity inventory, and labels unusable candidates `! invalid`.
Use `dots dev link <checkout>` only while testing unreleased code, and `dots dev
unlink` to return to the stable runtime.
