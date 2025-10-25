# {
#   flake.features.searxng.nixos =
#     { config, pkgs, ... }:
#     {
#       sops.secrets."searxng.env" = { };

#       services.nginx.virtualHosts.${config.services.searx.domain} = {
#         enableACME = true;
#         acmeRoot = null;
#         onlySSL = true;
#         kTLS = true;
#         locations."/" = {
#           # Yes this is correct without the ":"
#           proxyPass = "http://localhost${config.services.searx.uwsgiConfig.http}";
#         };
#       };

#       services.searx = {
#         enable = true;
#         domain = "searxng.${config.networking.domain}";
#         environmentFile = config.sops.secrets."searxng.env".path;
#         redisCreateLocally = true; # Needed for Rate-Limit & bot protection

#         configureUwsgi = true; # Recommended for public instances
#         uwsgiConfig.http = ":8888";

#         settings = {
#           general = {
#             enable_metrics = false;
#             open_metrics = "";
#           };

#           # Just enable all formats because why not ;)
#           search.formats = [
#             "html"
#             "csv"
#             "rss"
#             # NOTE: JSON is needed for Open-Webui
#             "json"
#           ];

#           server = {
#             secret_key = "$SECRET_KEY";
#             base_url = "https://${config.services.searx.domain}";
#             # FIXME: Limiter Settings aren't found according to logs.
#             #        They are stored under /etc/searxng/limiter.toml
#             #        bu should be stored in /run/searx/limiter.toml
#             # TODO: Open Issue in Nixpkgs about this and reenable this
#             # NOTE: Open-Webui Web Search working takes precedence
#             public_instance = false; # Enables rate limiting and bot detection
#             # Only 1.0 and 1.1 are supported.
#             # 1.0 was the default for whatever reason
#             http_protocol_version = "1.1";
#             image_proxy = true;
#           };

#           engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
#             "fdroid".disabled = false;
#             "geizhals".disabled = false;
#             "gitlab".disabled = false;
#             "codeberg".disabled = false;
#             "gitea.com".disabled = false;
#             "nixos wiki".disabled = false;
#             "hackernews".disabled = false;
#             "crates.io".disabled = false;
#             "huggingface".disabled = false;
#             "imdb".disabled = false;
#             "imgur".disabled = false;
#             "npm".disabled = false;
#             "odysee".disabled = false;
#             "ollama".disabled = false;
#             "reddit".disabled = false;
#             "rottentomatoes".disabled = false;
#             "selfhst icons".disabled = false;
#             "steam".disabled = false;
#             "tmdb".disabled = false;
#             "wallhaven".disabled = false;
#             "lib.rs".disabled = false;
#             "sourcehut".disabled = false;
#             "minecraft wiki".disabled = false;
#           };
#         };
#       };

#       # environment.persistence."/volatile".directories = [
#       #   {
#       #     directory = "/var/lib/private/ollama";
#       #     user = "ollama";
#       #     group = "ollama";
#       #     mode = "0755";
#       #   }
#       # ];

#     };
# }
{ }
