{
  lib,
  python3,
  makeWrapper,
  nixidyEnvs,
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

    # Create symlinks to environment packages and metadata files
    mkdir -p $out/share/nixidy-environments
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (env: nixidyEnv: ''
        ln -s ${nixidyEnv.environmentPackage} $out/share/nixidy-environments/${env}

        # Create metadata YAML file with configuration
        cat > $out/share/nixidy-environments/${env}.yaml <<'EOF'
        name: "${env}"
        repository: "${nixidyEnv.config.nixidy.target.repository}"
        branch: "${nixidyEnv.config.nixidy.target.branch}"
        rootPath: "${nixidyEnv.config.nixidy.target.rootPath}"
        EOF
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
