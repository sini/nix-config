# gen-lsp: the LSP/MCP projection tooling for the gen module stack. This flake
# ships `packages.<system>.mcp` (a hermetic Rust MCP enumeration server) and a
# pure-builtins `lib`. We consume the INPUT source here to build our own
# nixpkgs-style `gen-lsp-mcp` package (pkgs/by-name/gen-lsp-mcp), threaded to
# callPackage as `gen-lsp-src` by the overlay in pkgs/overlays.nix.
#
# `nixpkgs.follows` dedups gen-lsp's mcp-build nixpkgs onto ours.
{ ... }:
{
  flake-file.inputs.gen-lsp = {
    url = "github:sini/gen-lsp";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };
}
