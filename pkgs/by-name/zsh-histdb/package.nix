{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "zsh-histdb";
  version = "30797f0c50c31c8d8de32386970c5d480e5ab35d"; # commit as version

  src = fetchFromGitHub {
    owner = "larkery";
    repo = "zsh-histdb";
    rev = version;
    sha256 = "sha256-PQIFF8kz+baqmZWiSr+wc4EleZ/KD8Y+lxW2NT35/bg=";
  };

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/zsh-histdb
    cp -r * $out/share/zsh-histdb/
  '';
}
