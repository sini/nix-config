{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
  ffmpeg-headless,
}:
buildNpmPackage {
  pname = "hyperframes";
  version = "0.8.93";

  src = ./.;

  npmDepsHash = "sha256-pqXr+dA/onWHaa7p0QUATOn9504sJu76u8E8W2L2OHU=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/hyperframes \
      --add-flags "$out/lib/node_modules/hyperframes-cli/node_modules/hyperframes/bin/hyperframes.mjs" \
      --prefix PATH : ${
        lib.makeBinPath [
          ffmpeg-headless.bin
          nodejs
        ]
      } \
      --set HYPERFRAMES_FFMPEG_PATH "${ffmpeg-headless.bin}/bin/ffmpeg" \
      --set HYPERFRAMES_FFPROBE_PATH "${ffmpeg-headless.bin}/bin/ffprobe"

    makeWrapper ${nodejs}/bin/node $out/bin/hyperframes-localize-fonts \
      --add-flags "$out/lib/node_modules/hyperframes-cli/node_modules/hyperframes/bin/hyperframes-localize-fonts.mjs" \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}
  '';

  meta = {
    description = "Create and render HTML video compositions";
    homepage = "https://hyperframes.heygen.com";
    license = lib.licenses.asl20;
    mainProgram = "hyperframes";
  };
}
