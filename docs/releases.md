# Releases

The root `version` file specifies the release version. Stable releases use
semantic versions in the `X.Y.Z` format. Each release has a matching `vX.Y.Z`
Git tag. Update `version` before you create the tag. Commit the change before
you create the tag. The release build fails if the version and the tag do not
match. Publish each fix as a new version. Do not replace an existing release.

A version tag push starts the GitHub release workflow. The macOS and Ubuntu
jobs build and smoke-test the release output. The publish job downloads the
tested output from the Ubuntu job. It publishes this output without a new
build. The output contains these files:

- `dots-X.Y.Z.tar.gz`
- `install.sh`
- `SHA256SUMS`
- The `dots-release.txt` manifest that the updater can read

The generated installer specifies the archive name and SHA-256 checksum for
the release. It verifies the integrity of the artifact. It then runs the
packaged transactional installer. The release artifacts do not have
cryptographic signatures. Thus, the integrity check depends on the integrity
of the published checksum.

The archive contains only the versioned runtime files. It contains `bin`,
`config`, `default`, `install`, `migrations`, `themes`, and `version`. These
files are in a `dots-X.Y.Z` directory.

Use this command to build the same files locally from the current commit:

```bash
./scripts/build-release.sh vX.Y.Z
```

Use a second argument to specify an output directory. The build always reads
the committed `HEAD`. Thus, the build cannot include uncommitted files. On
Linux, use `sha256sum -c SHA256SUMS` to verify downloaded assets. On macOS, use
`shasum -a 256 -c SHA256SUMS`.

## Installed releases

The installer unpacks stable releases into
`~/.local/share/dots/releases/<version>`. The owned `current` and `previous`
symlinks permit runtime rollback. See
[`docs/update-process.md`](update-process.md#activation-and-rollback) for the
activation and recovery protocol. The editable checkout is independent of
these releases. It can contain local changes when `dots update` installs a
stable release.

A normal installation runs the `install.sh` file from the latest release. It
does not require a Git checkout. After installation, use these commands to
manage release bundles:

- `dots version install`
- `dots version list`
- `dots version rollback`
- `dots version prune`

The `dots version list` command verifies the ownership marker and the complete
integrity inventory for each candidate. It labels an unusable candidate as
`! invalid`.

The `dots version prune` command reconciles interrupted pointer updates. It
preserves the current and previous releases. It removes an inactive release
directory only if the ownership marker and the complete SHA-256 integrity
inventory are valid. It does not remove symlinks, malformed names, foreign
directories, or modified releases. It reports these invalid entries for manual
inspection.

Pruning requires interactive confirmation. Use `dots version prune --force`
only when you intentionally bypass confirmation. For example, use this option
in automation that cannot provide confirmation. The operation holds the update
lock that installation, activation, and rollback also use.

Use `dots dev link <checkout>` only to test unreleased code. Use
`dots dev unlink` to return to the stable runtime.
