# TODO: Rely on upstream once merged: https://github.com/NixOS/nixpkgs/pull/375287
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  procps,
  qt6Packages,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "moondeck-buddy";
  version = "1.9.2";

  src = fetchFromGitHub {
    owner = "FrogTheFrog";
    repo = "moondeck-buddy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GhZlmdI+oa5BjEzr9bkR2sY/nVpd1nuJlT2hYYv6zGU=";
    fetchSubmodules = true;
  };
  buildInputs = [
    procps
  ]
  ++ (with qt6Packages; [
    qtbase
    qthttpserver
    qtwebsockets
  ]);

  nativeBuildInputs = [
    cmake
    ninja
    qt6Packages.wrapQtAppsHook
  ];

  meta = {
    mainProgram = "MoonDeckBuddy";
    description = "Helper to work with moonlight on a steamdeck";
    homepage = "https://github.com/FrogTheFrog/moondeck-buddy";
    changelog = "https://github.com/FrogTheFrog/moondeck-buddy/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.lgpl3Only;
    platforms = lib.platforms.linux;
  };
})
