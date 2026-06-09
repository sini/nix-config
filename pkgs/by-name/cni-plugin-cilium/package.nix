{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
let
  # Single source of truth for the cilium version (see the comment there).
  cilium = import ../../../charts/cilium/cilium/default.nix;
in
buildGoModule rec {
  pname = "cilium-cni";
  inherit (cilium) version;

  src = fetchFromGitHub {
    owner = "cilium";
    repo = "cilium";
    rev = "v${version}";
    hash = cilium.srcHash;
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
