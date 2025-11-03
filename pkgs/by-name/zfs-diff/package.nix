{
  lib,
  python3,
  skim,
  makeWrapper,
}:

python3.pkgs.buildPythonApplication {
  pname = "zfs-diff-filter";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 zfs-diff-filter.py $out/bin/zfs-diff-filter

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/zfs-diff-filter \
      --add-flags "--skim-bin ${skim}/bin/sk"
  '';

  meta = {
    description = "Filter ZFS diff output by excluding persisted and ignored paths";
    mainProgram = "zfs-diff-filter";
    platforms = lib.platforms.linux;
  };
}
