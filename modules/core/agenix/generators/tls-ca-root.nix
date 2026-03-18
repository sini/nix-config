################################################################################
# Provide TLS certificate secret generation.
################################################################################

# TODO: TLS has a means of allowing certain features as well as how they
# propagate.  Allow this to be indicated and document how this is done.  For
# specifics on the features themselves, refer to some external documentation.
# This applies to this generator as well as the other, related generators.
{
  flake.features.agenix-generators.system =
    { lib, ... }:
    let
      helpers = import ./_helpers.nix { inherit lib; };
      inherit (helpers) subject-string validate-tls-settings;
    in
    {
      age.generators.tls-ca-root =
        {
          file,
          name,
          pkgs,
          secret,
          ...
        }:
        let
          inherit (lib) isAttrs;
          inherit (lib.trivial) throwIfNot;
          inherit (secret) settings;
        in
        throwIfNot (isAttrs settings) "Secret '${name}' must have a `settings` attrset."
          validate-tls-settings
          name
          settings.tls
          ''
            \
                 set -euo pipefail
                 ${pkgs.openssl}/bin/openssl req \
                    -new \
                    -newkey rsa:4096 \
                    -keyout root.key \
                    -x509 \
                    -nodes \
                    -out "$(dirname "${file}")/${name}.crt" \
                    -subj "/CN=${settings.tls.domain}${subject-string settings.tls.subject}" \
                    -days "${toString settings.tls.validity}"
                 cat root.key
                 rm root.key
          '';
    };
}
