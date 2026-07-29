{
  den.aspects.applications.dev.lang.rust = {
    nixpkgs-overlays =
      { inputs', ... }:
      [ inputs'.fenix.overlays.default ];

    homeManager =
      { pkgs, ... }:
      {
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
