{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "sf-mono";
  version = "0-unstable";

  src = fetchFromGitHub {
    owner = "shaunsingh";
    repo = "SFMono-Nerd-Font-Ligaturized";
    rev = "dc5a3e6";
    hash = "sha256-AYjKrVLISsJWXN6Cj74wXmbJtREkFDYOCRw1t2nVH2w=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/opentype
    cp -r $src/*.otf $out/share/fonts/opentype/

    runHook postInstall
  '';

  meta = {
    description = "SF Mono Nerd Font (ligaturized)";
    homepage = "https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized";
  };
}
