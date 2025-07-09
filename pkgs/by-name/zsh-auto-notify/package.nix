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
    rev = "${version}";
    sha256 = "sha256-8r5RsyldJIzlWr9+G8lrkHvJ8KxTVO859M//wDnYOUY=";
  };

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/zsh-auto-notify
    cp auto-notify.plugin.zsh $out/share/zsh-auto-notify/zsh-auto-notify.plugin.zsh
  '';
}
