# crate2nix stale hash cache repro

Demonstrates the stale `crate-hashes.json` bug in crate2nix for
branch-based git dependencies.

## The bug

When a Cargo dependency uses a git branch reference (e.g.,
`branch = "branch-for-test"`), crate2nix caches the prefetched SHA256
hash in `crate-hashes.json` under a key like:

```
git+https://github.com/kolloch/nix-base32?branch=branch-for-test#0.1.2-alpha.0
```

This key is the cargo PackageId, which includes the URL and version but
**not the commit hash**. When the branch moves to a new commit (same
version), the cache key is unchanged, so `crate2nix generate` reuses
the stale hash from the old commit. The generated `Cargo.nix` then
references the new commit with the old hash, causing `nix build` to
fail with a hash mismatch.

## Commits

### Commit 1: working build

- `Cargo.lock` points to commit `42f5544` (HEAD of `branch-for-test`)
- `crate-hashes.json` has the correct hash for that commit
- `nix build` succeeds

### Commit 2: broken build (stale hash)

- `crate-hashes.json` has a wrong hash (from a different commit) under
  the same cache key
- `crate2nix generate` was re-run but reused the cached hash (no
  "Prefetching" output)
- `nix build` fails:

```
error: hash mismatch in fixed-output derivation:
         specified: sha256-dltsfJzogW2IRclhCYy+meqlk0xyuYBg46oGJoANrMs=
            got:    sha256-3AZKeYRL4iiJriBpoOYQv/yrv+p67YUnjbMjsgpJLgQ=
```

## Reproduce

```bash
# Working build (commit 1)
git checkout HEAD~2
nix build        # succeeds

# Broken build (commit 2)
git checkout main
nix build        # fails: hash mismatch
```

## Root cause

The PackageId for branch-based git deps is
`git+URL?branch=X#version` with no commit hash embedded. This means
the `crate-hashes.json` cache key is stable across different commits
on the same branch (as long as the version stays the same). When the
branch moves forward, `crate2nix generate` finds a cache hit and skips
prefetching, producing a `Cargo.nix` with a stale hash.

## Workaround

Delete `crate-hashes.json` before regenerating:

```bash
rm crate-hashes.json
nix run github:nix-community/crate2nix -- generate
nix build  # succeeds
```

## Usage

The flake exposes crate2nix as an app called `generate`. Running it
invokes the `crate2nix` binary, so you still need to pass the
`generate` subcommand after `--`:

```bash
# These are equivalent ways to run crate2nix generate:
nix run .#generate -- generate
nix run github:nix-community/crate2nix -- generate

# Build the project
nix build

# Run the binary
./result/bin/repro
```

The `--` separates nix's arguments from the arguments passed to the
program. `nix run .#generate` resolves to the `crate2nix` binary, and
`generate` after `--` is the subcommand passed to that binary.
