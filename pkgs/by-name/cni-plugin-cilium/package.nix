{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
# The single GitHub-source pin for cilium: this builds the cni binary AND the
# cilium aspect's CRDs reuse this package's `src` (via config.flake.packages),
# so owner/repo/version/hash live here only. Bump with `update-pkgs
# cni-plugin-cilium` (nix-update). Held in update-pkgs' PINNED list so it tracks
# charts/cilium rather than whatever is latest upstream; pass --version to move
# it with the chart.
buildGoModule rec {
  pname = "cilium-cni";
  version = "1.20.1";

  src = fetchFromGitHub {
    owner = "cilium";
    repo = "cilium";
    rev = "v${version}";
    hash = "sha256-I6d6We7BxiXJQS5jAUbj04zoFCEk24pREzrp03UYfi4=";
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
