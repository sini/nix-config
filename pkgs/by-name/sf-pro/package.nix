{
  stdenvNoCC,
  fetchurl,
  undmg,
  p7zip,
}:
stdenvNoCC.mkDerivation {
  pname = "sf-pro";
  version = "0-unstable";

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
    hash = "sha256-W0sZkipBtrduInk0oocbFAXX1qy0Z+yk2xUyFfDWx4s=";
  };

  nativeBuildInputs = [
    undmg
    p7zip
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    undmg $src
    7z x "SF Pro Fonts.pkg"
    7z x "Payload~"

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/{opentype,truetype}
    find -name \*.otf -exec mv {} $out/share/fonts/opentype/ \;
    find -name \*.ttf -exec mv {} $out/share/fonts/truetype/ \;

    runHook postInstall
  '';

  meta = {
    description = "Apple SF Pro typeface";
    homepage = "https://developer.apple.com/fonts/";
  };
}
