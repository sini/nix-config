{ inputs, ... }:
{
  den.aspects.apps.dev.lang.rust = {
    homeManager =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [ inputs.fenix.overlays.default ];
        home.packages = [
          (pkgs.fenix.complete.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ])
          pkgs.rust-analyzer-nightly
          pkgs.cargo-edit
          pkgs.wasm-pack
          pkgs.wasm-bindgen-cli
        ];
      };
  };
}
