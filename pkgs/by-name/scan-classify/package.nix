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
    # The stock epsonds driver's tone curve for the FF-680W (lut_id 2), for --classify-lut.
    install -Dm644 epsonds-lut2.csv $out/share/scan-classify/epsonds-lut2.csv

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    python3 test-scan-classify.py $out/bin/scan-classify $out/share/scan-classify/epsonds-lut2.csv

    runHook postInstallCheck
  '';

  meta = {
    description = "Route the pages of a scanner batch to immich (photos) or paperless (documents)";
    mainProgram = "scan-classify";
    platforms = lib.platforms.linux;
  };
}
