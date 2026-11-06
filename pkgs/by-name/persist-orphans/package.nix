{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "persist-orphans";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 persist-orphans.py $out/bin/persist-orphans
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${./test_persist_orphans.py} $out/bin/persist-orphans
    runHook postInstallCheck
  '';

  meta = {
    description = "List data in impermanence's stores that no configured persist entry uses";
    mainProgram = "persist-orphans";
    platforms = lib.platforms.linux;
  };
}
