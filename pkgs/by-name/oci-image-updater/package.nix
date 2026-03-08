{
  lib,
  python3,
  makeWrapper,
  nix,
  skopeo,
  git,
  nix-prefetch-docker,
}:
python3.pkgs.buildPythonApplication {
  pname = "oci-image-updater";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = [ ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install the Python package
    mkdir -p $out/${python3.sitePackages}
    cp -r oci_image_updater $out/${python3.sitePackages}/

    # Create the executable wrapper
    mkdir -p $out/bin
    cat > $out/bin/oci-image-updater <<EOF
    #!${python3}/bin/python3
    import sys
    from oci_image_updater.__main__ import main
    sys.exit(main())
    EOF
    chmod +x $out/bin/oci-image-updater

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/oci-image-updater \
      --prefix PYTHONPATH : $out/${python3.sitePackages} \
      --prefix PATH : ${
        lib.makeBinPath [
          nix
          skopeo
          git
          nix-prefetch-docker
        ]
      }
  '';

  meta = {
    description = "Update OCI container image metadata for Nix flakes";
    mainProgram = "oci-image-updater";
    platforms = lib.platforms.linux;
  };
}
