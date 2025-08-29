{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "zsh-auto-notify";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "MichaelAquilina";
    repo = "${pname}";
    rev = "3e9bce0072240b1009e5ab380365453c3b243c62"; # 0.11.1
    hash = "sha256-1+HD4rerEu0uu4hWtMORBeAJJgIgXv65McnqOpaSIV8=";
  };

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/zsh-auto-notify
    cp auto-notify.plugin.zsh $out/share/zsh-auto-notify/zsh-auto-notify.plugin.zsh
  '';
}
