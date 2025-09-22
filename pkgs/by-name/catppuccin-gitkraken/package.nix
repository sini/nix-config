{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-gitkraken";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "gitkraken";
    rev = version;
    hash = "sha256-df4m2WUotT2yFPyJKEq46Eix/2C/N05q8aFrVQeH1sA=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp themes/catppuccin-*.jsonc $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "Soothing pastel theme for GitKraken";
    homepage = "https://github.com/catppuccin/gitkraken";
    license = licenses.mit;
  };
}
