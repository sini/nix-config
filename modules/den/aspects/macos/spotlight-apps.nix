# Make nixpkgs GUI apps discoverable by Spotlight and Launchpad.
#
# home-manager symlinks app bundles into the Nix store, but Spotlight refuses to
# index apps that live behind symlinks outside ~/Applications. This copies each
# bundle's metadata (Info.plist, icons) into "~/Applications/Nix Apps" and
# symlinks the executable payload, so the apps show up in search/Launchpad while
# staying garbage-collectable.
# Ref: https://github.com/nix-community/home-manager/issues/1341
{
  den.aspects.macos.spotlight-apps.homeDarwin =
    { lib, ... }:
    {
      home.activation.copyNixApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nixApps="$HOME/Applications/Nix Apps"
        rm -rf "$nixApps"
        mkdir -p "$nixApps"

        for appLink in "$newGenPath/home-path/Applications/"*; do
          [ -e "$appLink" ] || continue
          appSource="$(readlink -f "$appLink")"
          appName="$(basename "$appSource")"
          target="$nixApps/$appName"

          mkdir -p "$target/Contents"
          [ -f "$appSource/Contents/Info.plist" ] && cp -f "$appSource/Contents/Info.plist" "$target/Contents/"
          if [ -d "$appSource/Contents/Resources" ]; then
            mkdir -p "$target/Contents/Resources"
            find "$appSource/Contents/Resources" -name "*.icns" -exec cp -f {} "$target/Contents/Resources/" \;
          fi
          # Symlink everything else (MacOS binary dir, frameworks, etc.).
          for sub in "$appSource/Contents"/*; do
            name="$(basename "$sub")"
            case "$name" in
              Info.plist | Resources) ;;
              *) ln -sfn "$sub" "$target/Contents/$name" ;;
            esac
          done
        done
      '';
    };
}
