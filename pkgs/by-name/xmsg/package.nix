# xmsg — lists running agent sessions and delivers messages into them over HTTP
# (anonymous callers) and Unix sockets (attested agent callers).
#
# A fresh buildRustPackage over the locked `xmsg` input (threaded as `xmsg-src` by
# pkgs/overlays.nix), NOT a re-export of xmsg's own `packages.default`. Cargo deps
# vendor from the committed lockfile, so the build is hermetic. The test suite
# uses only tempdir fixtures and stand-in sockets, so it runs in the sandbox.
{
  lib,
  rustPlatform,
  xmsg-src,
}:
rustPlatform.buildRustPackage {
  pname = "xmsg";
  version = "0.1.0";

  src = xmsg-src;
  cargoLock.lockFile = "${xmsg-src}/Cargo.lock";

  # Link rusqlite's bundled SQLite, the one xmsg's CI tests: the observe collector
  # refuses its store on any other SQLite version (its journal bound is derived from
  # the bundled source). nixpkgs' cargo setup hook exports
  # LIBSQLITE3_SYS_USE_PKG_CONFIG=1 in preConfigure; preBuild runs later, so this wins
  # for the build and the check phase alike.
  preBuild = ''
    export LIBSQLITE3_SYS_USE_PKG_CONFIG=0
  '';

  meta = {
    description = "Bridge into running Claude Code, Antigravity and pi sessions";
    homepage = "https://github.com/sini/xmsg";
    mainProgram = "xmsg";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
