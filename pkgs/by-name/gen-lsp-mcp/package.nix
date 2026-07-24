# gen-lsp-mcp — the gen-lsp enumeration MCP server (stdio, read-only). It projects
# a den/gen fleet's option / aspect / gen-lib API surface to coding agents as MCP
# tools, killing agent API hallucination. It embeds no Nix evaluator: every tool
# shells out to the customer's `nix` from PATH at runtime.
#
# A fresh buildRustPackage over the mcp/ subdir of the locked `gen-lsp` input
# (threaded as `gen-lsp-src` by pkgs/overlays.nix), NOT a re-export of gen-lsp's
# own `packages.<system>.mcp`. Cargo deps vendor from the committed lockfile, so
# the build is hermetic.
{
  lib,
  rustPlatform,
  gen-lsp-src,
}:
rustPlatform.buildRustPackage {
  pname = "gen-lsp-mcp";
  version = "0.1.0";

  # gen-lsp is a mixed tree (pure-Nix lib/ + ci/, the Rust server under mcp/):
  # source the mcp/ subdir directly so its Cargo.lock sits at the source root
  # (what the cargo-vendor consistency hook validates), same as gen-lsp's own
  # flake package (`src = ./mcp`).
  src = "${gen-lsp-src}/mcp";
  cargoLock.lockFile = "${gen-lsp-src}/mcp/Cargo.lock";

  # The cargo-test smoke suite needs `nix` on PATH + a fleet, neither available in
  # the build sandbox (gen-lsp's own package sets this too). The hermetic build
  # only compiles the binary; the server drives the customer's `nix` at runtime.
  doCheck = false;

  meta = {
    description = "MCP enumeration server for a den/gen fleet's API surface (drives the customer's nix)";
    mainProgram = "gen-lsp-mcp";
    license = lib.licenses.mit;
  };
}
