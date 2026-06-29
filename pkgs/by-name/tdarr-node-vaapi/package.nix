# Custom tdarr_node OCI image: stock haveagitgat/tdarr_node base + nixpkgs
# ffmpeg-full (av1_vaapi) + mesa, so the axon AMD Radeon 780M (VCN 4.0) APUs can
# hardware-encode AV1 via VAAPI. tdarr is pointed at it via the `ffmpegPath` env.
#
# WHY: the stock tdarr_node image ships Ubuntu Mesa too old for VCN4 AV1 VAAPI
# encode (needs Mesa >= 24.1); we supply nixpkgs mesa 26.x + ffmpeg-full.
#
# Three non-obvious things this build gets right (each cost a debugging round):
#   1. NO `contents`/copyToRoot. Copying ffmpeg-full+mesa to the image root makes
#      /bin and /lib directories that, under the container's overlayfs, SHADOW the
#      base Ubuntu usrmerge symlinks (/bin -> usr/bin) — deleting /bin/sh and
#      breaking /init's `#!/bin/sh` shebang ("exec /init: no such file or
#      directory"). Instead the ffmpeg+mesa store paths enter the image as the
#      closure of the wrappers that config.Env references, leaving the base rootfs
#      untouched.
#   2. The ffmpeg wrappers carry a LITERAL `#!/bin/sh` shebang so they run under the
#      image's Ubuntu dash, NOT nix bash. The base sets
#      LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu, which takes precedence over a nix
#      binary's RUNPATH — so a nix-shebang wrapper's own interpreter loads Ubuntu
#      glibc and dies ("symbol lookup error ... GLIBC_PRIVATE") before it can unset
#      anything. Ubuntu dash expects Ubuntu libc, starts fine, and drops
#      LD_LIBRARY_PATH before exec'ing the nix ffmpeg.
#   3. With LD_LIBRARY_PATH dropped, the nix ffmpeg resolves its samba/jansson/glibc
#      deps from its own closure instead of Ubuntu's older libs (which otherwise
#      throw `GLIBC_2.42`/`JANSSON_4` not found). The wrapper also sets the VAAPI env.
#
# GOTCHA: dockerTools.buildLayeredImage with `fromImage` merges ONLY `Env` — it
# does NOT inherit Entrypoint/Cmd/WorkingDir/User. Restated below from
# `skopeo inspect --config docker://ghcr.io/haveagitgat/tdarr_node:latest`:
#   Entrypoint = ["/init"];  Cmd = null;  WorkingDir = "/";  User = null;
#
# Rebuild / ship flow: `nix build .#tdarr-node-vaapi --option sandbox true` ->
# `nix copy --to ssh://uplink <out>` -> on uplink `skopeo copy docker-archive:<out>
# docker://localhost:5000/tdarr-node:av1` -> update the digest in
# images/json64/tdarr-node.
{
  dockerTools,
  ffmpeg-full,
  mesa,
  writeTextFile,
  symlinkJoin,
}:
let
  base = dockerTools.pullImage {
    imageName = "ghcr.io/haveagitgat/tdarr_node";
    imageDigest = "sha256:a0f47ec35dae7bfec7674a4d5749efe91c3a06ceb15ea038ff0dd83132f8568e";
    sha256 = "sha256-/9eIz08OuwdT5x2HTq8ZnjEDuQz10kbutBy8AofTonA=";
    finalImageName = "tdarr_node";
    finalImageTag = "base";
  };

  # ffmpeg/ffprobe wrappers — see header points 2 & 3. Literal `#!/bin/sh` so the
  # image's Ubuntu dash runs them, drops the base LD_LIBRARY_PATH, sets VAAPI, then
  # exec's the nix binary. tdarr derives ffprobe from ffmpegPath's sibling, so ship
  # both under one bin/.
  mkWrap =
    name:
    writeTextFile {
      name = "tdarr-${name}";
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!/bin/sh
        unset LD_LIBRARY_PATH
        export LIBVA_DRIVERS_PATH=${mesa}/lib/dri
        export LIBVA_DRIVER_NAME=radeonsi
        exec ${ffmpeg-full}/bin/${name} "$@"
      '';
    };
  tdarr-ffmpeg = symlinkJoin {
    name = "tdarr-ffmpeg";
    paths = [
      (mkWrap "ffmpeg")
      (mkWrap "ffprobe")
    ];
  };
in
dockerTools.buildLayeredImage {
  name = "tdarr-node-vaapi";
  tag = "av1";
  fromImage = base;
  config = {
    # Merged with the base image Env. ffmpegPath -> our wrapper, whose closure
    # pulls ffmpeg-full + mesa into the image without touching the base rootfs.
    Env = [
      "ffmpegPath=${tdarr-ffmpeg}/bin/ffmpeg"
    ];
    Entrypoint = [ "/init" ];
    WorkingDir = "/";
  };
}
