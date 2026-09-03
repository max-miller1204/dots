# Releases

The root `version` file is the release version source of truth. Releases use
stable semantic versions (`X.Y.Z`) and matching Git tags (`vX.Y.Z`). Update and
commit `version` before creating the tag; the release build fails if they do not
match. Publish fixes as a new version rather than replacing an existing release.

Pushing a version tag runs the GitHub release workflow. Its macOS and Ubuntu
jobs build and smoke-test the release outputs; the publish job downloads and
publishes the Ubuntu job's tested outputs without rebuilding them. Those
outputs are `dots-X.Y.Z.tar.gz`, `install.sh`, `SHA256SUMS`, and the
updater-readable `dots-release.txt` manifest. The generated installer pins that
release's archive name and SHA-256; it checks the artifact's integrity before
delegating to the packaged transactional installer. Release artifacts are not
cryptographically signed, so this check depends on the published checksum
remaining trustworthy. The archive contains only the versioned runtime payload:
`bin`, `config`, `default`, `install`, `migrations`, `themes`, and `version`,
under a `dots-X.Y.Z` directory.

To build the same files locally from the current commit:

```bash
./scripts/build-release.sh vX.Y.Z
```

Pass a second argument to choose an output directory. The build always reads
committed `HEAD`, so uncommitted files cannot leak into a release. Verify
downloaded assets with `sha256sum -c SHA256SUMS` on Linux or
`shasum -a 256 -c SHA256SUMS` on macOS.

## Installed releases

Stable releases are unpacked into `~/.local/share/dots/releases/<version>`.
Owned `current` and `previous` symlinks provide runtime rollback. Their
activation and recovery protocol is described in
[`docs/update-process.md`](update-process.md#activation-and-rollback). The
editable checkout is independent and may remain dirty while stable
`dots update` installs releases.

Normal installations run the latest release's `install.sh` directly and do not
require a Git checkout. Use `dots version install`, `dots version list`,
`dots version rollback`, and `dots version prune` to manage bundles afterward.
`dots version list` verifies
each candidate's ownership marker and complete integrity inventory, and labels
unusable candidates `! invalid`.

`dots version prune` reconciles interrupted pointer updates, preserves both the
current and previous releases, and removes only older release directories whose
ownership marker and full SHA-256 integrity inventory still verify. Symlinks,
malformed names, foreign directories, and modified releases are never removed;
they are reported as skipped invalid entries for manual inspection. Pruning
requires interactive confirmation. Use `dots version prune --force` only when
that confirmation is intentionally unnecessary, such as in automation. The
operation holds the same update lock used by installation, activation, and
rollback.

Use `dots dev link <checkout>` only while testing unreleased code, and `dots dev
unlink` to return to the stable runtime.
