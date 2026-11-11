{
  lib,
  python3,
}:
python3.pkgs.buildPythonApplication {
  pname = "agent-quota";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 agent-quota.py $out/bin/agent-quota
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${./test_agent_quota.py} $out/bin/agent-quota
    runHook postInstallCheck
  '';

  meta = {
    description = "Print the remaining weekly usage quota of the agy, codex and claude agents";
    mainProgram = "agent-quota";
    platforms = lib.platforms.unix;
  };
}
