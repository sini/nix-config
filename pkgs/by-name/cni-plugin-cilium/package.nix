{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
# The single GitHub-source pin for cilium: this builds the cni binary AND the
# cilium aspect's CRDs reuse this package's `src` (via config.flake.packages),
# so owner/repo/version/hash live here only. Bump with `update-pkgs
# cni-plugin-cilium` (nix-update). Pinned to a 1.20 pre-release deliberately —
# nix-update would otherwise pick latest stable; pass --version until GA.
buildGoModule rec {
  pname = "cilium-cni";
  version = "1.20.0-pre.3";

  src = fetchFromGitHub {
    owner = "cilium";
    repo = "cilium";
    rev = "v${version}";
    hash = "sha256-btHPdHHSFtKkfXrd9vVKlrOjWiCUM0dw9a5RbfJlyPg=";
  };

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=${version}"
    "-X main.Program=cilium"
  ];

  subPackages = [ "./plugins/cilium-cni" ];

  doCheck = false;

  meta = with lib; {
    description = "Cilium CNI plugin";
    homepage = "https://github.com/cilium/cilium/";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ starcraft66 ];
  };
}
