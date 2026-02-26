{
  lib,
  python3,
  makeWrapper,
  nix,
  sops,
  jq,
  yq,
  rsync,
  git,
  vals,
}:
python3.pkgs.buildPythonApplication {
  pname = "k8s-update-manifests";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = [ python3.pkgs.pyyaml ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 k8s-update-manifests.py $out/bin/k8s-update-manifests

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/k8s-update-manifests \
      --prefix PATH : ${
        lib.makeBinPath [
          nix
          sops
          jq
          yq
          rsync
          git
          vals
        ]
      }
  '';

  meta = {
    description = "Update Kubernetes manifests for nixidy environments";
    mainProgram = "k8s-update-manifests";
    platforms = lib.platforms.linux;
  };
}
