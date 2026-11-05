{
  lib,
  python3,
}:

python3.pkgs.buildPythonApplication {
  pname = "scan-classify";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  dependencies = [ python3.pkgs.pillow ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 scan-classify.py $out/bin/scan-classify

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    python3 test-scan-classify.py $out/bin/scan-classify

    runHook postInstallCheck
  '';

  meta = {
    description = "Route the pages of a scanner batch to immich (photos) or paperless (documents)";
    mainProgram = "scan-classify";
    platforms = lib.platforms.linux;
  };
}
