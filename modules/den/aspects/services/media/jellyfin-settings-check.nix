# The Jellyfin aspect's jellarr setting (services.media.jellyfin.settings.jellarr),
# read from uplink's settings and called for a sample instance, against what jellarr and both instances rely on:
#   escape     a `${` in a rendered value becomes `$${` (jellarr's literal `${`), and
#              any other `$` is left as written
#   libraries  the 8 declared names, matching uplink's virtual folders
#   admin      the only declared user, with a passwordFile and no inline password
#   pins       the plugins are pinned to uplink's installed versions
#   json       render is valid JSON (so valid YAML) that round-trips to the escaped
#              config
#   nix build .#checks.x86_64-linux.jellyfin-settings
{ config, lib, ... }:
let
  jellarr = config.den.hosts.x86_64-linux.uplink.settings.services.media.jellyfin.jellarr;
  args = {
    baseUrl = "http://127.0.0.1:8096";
    domain = "jellyfin.example.test";
    adminPasswordFile = "/run/secrets/jellyfin/admin-password";
    knownProxies = [ "127.0.0.1" ];
    hardwareDecodingCodecs = [
      "h264"
      "hevc"
    ];
  };
  cfg = jellarr args;
  # Values the setting renders (the domain reaches the SSO button): one with `${`,
  # one with a lone `$` and a `$$`, which must pass through untouched.
  brace = jellarr (args // { domain = "jf\${x}.example.test"; });
  plain = jellarr (args // { domain = "jf$5$$6.example.test"; });
  names = map (f: f.name) cfg.library.virtualFolders;
  checks = {
    escape = lib.hasInfix "https://jf$\${x}.example.test/sso" brace.branding.loginDisclaimer;
    untouched = lib.hasInfix "https://jf$5$$6.example.test/sso" plain.branding.loginDisclaimer;
    libraries =
      names == [
        "Movies"
        "Shows"
        "Anime"
        "AnimeMovies"
        "Books"
        "Music"
        "MusicVideos"
        "Concerts"
      ];
    admin =
      map (u: u.name) cfg.users == [ "Admin" ]
      && (lib.head cfg.users) ? passwordFile
      && !((lib.head cfg.users) ? password);
    pins = lib.all (p: p ? version) cfg.plugins;
    json = builtins.fromJSON (builtins.toJSON cfg) == cfg;
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.jellyfin-settings = pkgs.runCommand "jellyfin-settings" { } (
        if failed == [ ] then
          "touch $out"
        else
          "echo 'jellyfin-settings failed: ${lib.concatStringsSep ", " failed}' >&2; exit 1"
      );
    };
}
