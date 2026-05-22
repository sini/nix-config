# srl files can created during the leaf certificate creation.  The files track
# which serial numbers have been used (for auditing?) so openssl won't use the
# same one twice.  This should be checked in.
{
  features.agenix-generators.system =
    { lib, ... }:
    let
      helpers = import ./_helpers.nix { inherit lib; };
      inherit (helpers) subject-string;
    in
    {
      age.generators.tls-signed-certificate =
        {
          decrypt,
          deps,
          file,
          name,
          pkgs,
          secret,
          ...
        }:
        let
          inherit (lib) isAttrs isString;
          inherit (lib.trivial) throwIfNot;
          inherit (secret) settings;
          root-cert-dep = builtins.elemAt deps 0;
        in
        throwIfNot (isAttrs settings) "Secret '${name}' must have a `settings` attrset." throwIfNot
          (isString settings.fqdn)
          "Secret '${name}' is missing a `fqdn` string."
          # throwIfNot (isAttrs settings.root-certificate) "Secret '${name}' is missing a `root-certificate` value."
          ''
            set -euo pipefail
            ${decrypt} "${root-cert-dep.file}" > ca.key
            cert_path="$(dirname "${root-cert-dep.file}")/${root-cert-dep.name}.crt"
            out_file="$(dirname "${file}")/$(basename ${name} '.key').crt"
            ${pkgs.openssl}/bin/openssl req \
               -new \
               -newkey rsa:4096 \
               -sha256 \
               -nodes \
               -keyout signing.key \
               -out signing.crt \
               -subj "/CN=${settings.fqdn}${subject-string settings.root-certificate.settings.tls.subject}" \
               -addext "subjectAltName = DNS:${settings.fqdn}"
            echo "subjectAltName = DNS:${settings.fqdn}" > san.cnf
            ${pkgs.openssl}/bin/openssl x509 \
               -req \
               -in signing.crt \
               -CA $cert_path \
               -CAkey ca.key \
               -CAcreateserial \
               -out $out_file \
               -days 356 \
               -extfile san.cnf
            # Verify it works!
            ${pkgs.openssl}/bin/openssl verify \
              -CAfile $cert_path \
              $out_file \
              1>&2
            cat signing.key
            rm ca.key
            rm san.cnf
            rm signing.{crt,key}
          '';
    };
}
