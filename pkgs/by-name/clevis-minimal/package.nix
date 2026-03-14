# Minimal cross-platform fork of Clevis for Tang-based network encryption
#
# This fork removes Linux-only dependencies (cryptsetup, luksmeta, tpm2-tools)
# to enable Darwin systems to provision NixOS hosts with Tang disk encryption.
#
# See README.md for full rationale and usage examples.
{
  lib,
  asciidoc-full,
  coreutils,
  curl,
  fetchFromGitHub,
  fetchpatch,
  gnugrep,
  gnused,
  jansson,
  jose,
  makeWrapper,
  meson,
  ninja,
  pkg-config,
  stdenv,
}:

let
  # jose v14 is marked broken on Darwin in nixpkgs because its meson build passes
  # `-export-symbols-regex=^jose_.*` — a GNU ld flag that Apple's clang linker
  # doesn't understand. We apply the upstream fix (PR #163) which uses the
  # Darwin-compatible `-exported_symbol` flag instead, then unmark it as broken.
  # https://github.com/latchset/jose/pull/163
  jose-fixed = jose.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ lib.optionals stdenv.hostPlatform.isDarwin [
      (fetchpatch {
        url = "https://github.com/latchset/jose/commit/228d6782235238ed0d03eb2443caf530b377ffd5.patch?full_index=1";
        hash = "sha256-PQGHp+ereU3Qx1IfXV89VI/ao0deBrosmH25h1jRvME=";
      })
    ];
    meta = old.meta // {
      broken = false;
    };
  });
in

stdenv.mkDerivation (finalAttrs: {
  pname = "clevis-minimal";
  version = "21";

  src = fetchFromGitHub {
    owner = "latchset";
    repo = "clevis";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2vDQP+yvH4v46fLEWG/37r5cYP3OeDfJz71cDHEGiUg=";
  };

  patches = [
    # Replaces the clevis-decrypt 300s timeout to a 10s timeout
    # https://github.com/latchset/clevis/issues/289
    ./0000-tang-timeout.patch
    # Make cryptsetup optional in LUKS tests for minimal build
    ./0001-make-cryptsetup-optional.patch
  ];

  nativeBuildInputs = [
    asciidoc-full # For generating man pages
    makeWrapper
    meson
    ninja
    pkg-config
  ];

  # Minimal runtime dependencies for Tang encryption only.
  # Excluded from upstream: cryptsetup, luksmeta, libpwquality, tpm2-tools
  # (all Linux-only or hardware-specific)
  buildInputs = [
    curl # For HTTP requests to Tang servers
    jansson # JSON parsing
    jose-fixed # JWE/JWK cryptographic operations
  ];

  outputs = [
    "out"
    "man"
  ];

  # TODO: Investigate cross-compilation setup to enable strictDeps.
  # Current upstream package also has strictDeps = false.
  strictDeps = false;

  # Disable tests because:
  # 1. Most tests require LUKS devices (not available in Nix sandbox or on Darwin)
  # 2. Tests need cryptsetup binary (Linux-only, excluded from this minimal build)
  # 3. Our patch makes cryptsetup optional but doesn't provide mock devices
  # The Tang encryption functionality we need is well-tested upstream.
  doCheck = false;

  # Upstream hardcodes /bin/cat in several shell scripts since 2018-07-11.
  # We patch all occurrences to use the Nix store path for coreutils cat.
  # See: https://github.com/latchset/clevis/issues/61
  postPatch = ''
    for f in $(find src/ -type f -print0 |\
                 xargs -0 -I@ sh -c 'grep -q "/bin/cat" "$1" && echo "$1"' sh @); do
      substituteInPlace "$f" --replace-fail '/bin/cat' '${lib.getExe' coreutils "cat"}'
    done
  '';

  # Wrap the main clevis binary to ensure all runtime dependencies are in PATH.
  # The clevis script dispatches to various sub-commands (clevis-encrypt-tang,
  # clevis-encrypt-sss, etc.) which need these tools available at runtime.
  postInstall =
    let
      includeIntoPath = [
        coreutils # Various utilities (cat, base64, etc.)
        gnugrep # Pattern matching in scripts
        gnused # Text transformations
        jose-fixed # JWE/JWK crypto operations
        curl # HTTP requests to Tang servers
      ];
    in
    ''
      wrapProgram $out/bin/clevis \
        --prefix PATH ':' "${lib.makeBinPath includeIntoPath}:${placeholder "out"}/bin"
    '';

  meta = {
    homepage = "https://github.com/latchset/clevis";
    description = "Automated Encryption Framework (minimal build for Tang encryption)";
    longDescription = ''
      Clevis is a pluggable framework for automated decryption. This is a minimal
      build focused on Tang-based encryption, suitable for cross-platform use including
      Darwin. LUKS-specific features require Linux.
    '';
    changelog = "https://github.com/latchset/clevis/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    mainProgram = "clevis";
    platforms = lib.platforms.unix;
  };
})
