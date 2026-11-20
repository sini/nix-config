# Scope: stale lower-store views in persistent-store guests

Status: scoping, 2026-11-20. Extends docs/microvm-persistent-store.md §4 ("A
path that appears in the lower layer can stay hidden").

## Problem

A persistent-store guest (uplink-dev) mounts its store as an overlay. The lower
layer is the host's `/nix/store` over virtiofs (`/nix/.ro-store`, `cache=auto`,
`--inode-file-handles=prefer`). Above it is the guest's writable layer. When the
host adds a path while the guest is looking at it, the guest can keep a stale
view:

- **Missing path** (§4, measured 2026-11-10). The guest looked the path up
  before the host had it, so `/nix/store/<path>` answers ENOENT after the host
  adds it.
- **Empty path** (new, measured 2026-11-20). The guest registered `2dd1rz…-ci`
  in the same second the host wrote it (host ctime = guest registrationTime
  1795156981). The guest listed the directory as empty, and
  `nix-store --verify-path` reported "was modified!".
  - The host's copy was complete, and the guest's upper layer held nothing for
    it.
  - Nix restores a substituted or built path directly into its final directory,
    so the directory exists empty while its contents are written. The guest
    cached that moment.
  - `echo 2 > /proc/sys/vm/drop_caches` in the guest cleared it; the path then
    verified.

Either way a guest tool breaks until something drops the guest's caches. §2.6's
reconcile does, but only on a run that reaches step 5 with missing rows, so
today nothing bounds how long a stale view lasts.

## What we don't know yet

With `cache=auto`, FUSE re-checks a cached entry after its 1 s timeout, so
virtiofs alone should have healed this within a second. Something holds it
longer. There are two candidates:

1. **Modification time.** FUSE keeps a cached directory listing while the
   directory's mtime is unchanged. Nix canonicalises every store path's mtime to
   1 (`Dec 31 1969`), so a directory first seen empty, and later seen full, can
   look unchanged.
2. **OverlayFS.** Overlay caches its own dentries and merged-directory listings
   above virtiofs, and it doesn't watch the lower layer for changes. The kernel
   documentation says changing a mounted lower is undefined.

The fix depends on which it is, so the first step is a test.

## Step 1: find the mechanism (read-only for Nix's database)

A throwaway directory in the host's store, never registered with Nix, so nothing
references it:

1. On the host, create an empty
   `/nix/store/00000000000000000000000000000000-stale-probe`.
2. In the guest, `ls` it, through both the overlay (`/nix/store/…`) and the raw
   lower (`/nix/.ro-store/…`).
3. On the host, add a file to it. Run two variants: one leaving its mtime as is,
   one resetting the directory's mtime to 1, the way Nix does.
4. In the guest, after 2 s and again after 30 s, `ls` both views.
5. Remove the probe on the host.

Reading the results:

- Both views heal within 2 s in the plain variant, and only the mtime-1 variant
  stays stale: candidate 1, FUSE's listing cache.
- `/nix/.ro-store` heals but `/nix/store` doesn't: candidate 2, OverlayFS.

The test writes one unregistered directory into the host's store and removes it.
Nix's database and every real path are untouched. It needs the owner's OK, since
it writes to `/nix/store` outside Nix.

## Candidate fixes, by mechanism

| Mechanism                  | Fix                                                                                                                                                                                                           | Cost                                                                                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| FUSE listing cache (mtime) | virtiofsd `--cache=metadata` (or `never`) on the ro-store share: no directory-listing or data cache, entries still time out                                                                                   | more FUSE round trips per lookup; measure a `nix build` and a GC before and after                                  |
| OverlayFS                  | invalidate when the guest gains a lower path: drop caches after any registration from the lower (a `post-build-hook` misses substitutions, so a hook on the guest's store), or run it every 15 min regardless | `drop_caches` empties the guest's whole page cache, a one-off cost per run that grows with the guest's working set |
| Either, as a floor         | §2.6's reconcile drops caches on every run, not only on runs with missing rows                                                                                                                                | at most 15 min of staleness, same `drop_caches` cost every 15 min                                                  |

**Recommendation.**

- Ship the floor now. It's a one-line change to the reconcile, and it puts an
  upper bound on staleness whichever mechanism this turns out to be.
- Then run step 1 and fix the actual mechanism. If it's FUSE, `--cache=metadata`
  heals within a second, with no guest-side machinery. If it's OverlayFS, a
  targeted invalidation is needed, because the kernel offers no way to
  revalidate a lower layer.

## Not in scope

- Changing Nix's restore order upstream (temp directory plus rename).
- Moving guests off local-overlay.
