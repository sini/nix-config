{
  lib,
  python3,
  makeWrapper,
  nix,
  nix-fast-build,
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

    # Install the Python package
    mkdir -p $out/${python3.sitePackages}
    cp -r k8s_update_manifests $out/${python3.sitePackages}/

    # Create the executable wrapper
    mkdir -p $out/bin
    cat > $out/bin/k8s-update-manifests <<EOF
    #!${python3}/bin/python3
    import sys
    from k8s_update_manifests.__main__ import main
    sys.exit(main())
    EOF
    chmod +x $out/bin/k8s-update-manifests

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/k8s-update-manifests \
      --prefix PYTHONPATH : $out/${python3.sitePackages} \
      --prefix PATH : ${
        lib.makeBinPath [
          nix
          nix-fast-build
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
