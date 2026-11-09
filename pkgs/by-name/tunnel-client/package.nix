# openai/tunnel-client: the Secure MCP Tunnel client (init / doctor / run). Built from
# source; update-pkgs (nix-update) bumps it. The admin UI is embedded from the committed
# pkg/adminui/assets, and the version from pkg/version/VERSION, so the plain Go build
# needs neither the node toolchain nor version ldflags.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "tunnel-client";
  version = "0.0.20";

  src = fetchFromGitHub {
    owner = "openai";
    repo = "tunnel-client";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fWC6zejkzzYjqXxm1TsXJL6Tuyr1ib1hqffGAfFhyBo=";
  };

  vendorHash = "sha256-vX4YnYqvaJYnkfdtTmJccvwWVybE5gSGizCHxLykWDU=";

  subPackages = [ "cmd/client" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
  # The suite needs network and a live control plane (e2e, harpoon integration).
  doCheck = false;

  postInstall = ''
    mv $out/bin/client $out/bin/tunnel-client
  '';

  meta = {
    description = "OpenAI Secure MCP Tunnel client";
    homepage = "https://github.com/openai/tunnel-client";
    license = lib.licenses.asl20;
    mainProgram = "tunnel-client";
    platforms = lib.platforms.unix;
  };
})
