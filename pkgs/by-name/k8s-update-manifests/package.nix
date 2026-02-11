{
  lib,
  python3,
  makeWrapper,
  nixidyEnvs,
  sops,
  jq,
  yq,
  rsync,
}:
python3.pkgs.buildPythonApplication {
  pname = "k8s-update-manifests";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 k8s-update-manifests.py $out/bin/k8s-update-manifests

    # Create symlinks to environment packages
    mkdir -p $out/share/nixidy-environments
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (env: nixidyEnv: ''
        ln -s ${nixidyEnv.environmentPackage} $out/share/nixidy-environments/${env}
      '') nixidyEnvs
    )}

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/k8s-update-manifests \
      --prefix PATH : ${
        lib.makeBinPath [
          sops
          jq
          yq
          rsync
        ]
      }
  '';

  meta = {
    description = "Update Kubernetes manifests for nixidy environments";
    mainProgram = "k8s-update-manifests";
    platforms = lib.platforms.linux;
  };
}
