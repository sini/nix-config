{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "feather";
  version = "0-unstable-2020-02-04";

  src = fetchFromGitHub {
    owner = "AT-UI";
    repo = "feather-font";
    rev = "2ac71612ee85b3d1e9e1248cec0a777234315253";
    hash = "sha256-W4CHvOEOYkhBtwfphuDIosQSOgEKcs+It9WPb2Au0jo=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype
    cp -r $src/src/fonts/*.ttf $out/share/fonts/truetype/

    runHook postInstall
  '';

  meta = {
    description = "Feather icon font";
    homepage = "https://github.com/AT-UI/feather-font";
  };
}
