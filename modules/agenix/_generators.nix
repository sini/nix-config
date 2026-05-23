# Standalone NixOS module providing custom agenix-rekey secret generators.
# Imported by both the den agenix-generators aspect (for host builds) and
# the nixidy assembly (for kubernetes secret generation).
#
# This file is NOT a flake-parts module — it's a plain NixOS module.
# import-tree will skip it because it's consumed explicitly.
{ config, lib, ... }:
let
  # Helper functions for TLS generators
  subject-string = subject: ''
    /C=${subject.country}\
    /ST=${subject.state}\
    /L=${subject.location}\
    /O=${subject.organization}\
    /OU=${subject.organizational-unit}'';

  validate-tls-settings =
    let
      inherit (lib) isAttrs isInt isString;
      inherit (lib.trivial) id throwIfNot;
    in
    name: tls:
    throwIfNot (isAttrs tls) "Secret '${name}' must have a `tls` attrset." throwIfNot
      (isString tls.domain)
      "Secret '${name}' must have a `tls.domain` string."
      throwIfNot
      (isInt tls.validity)
      "Secret '${name}' must have a `tls.validity` integer."
      (validate-tls-subject name tls.subject)
      id;

  validate-tls-subject =
    let
      inherit (lib) isAttrs isString;
      inherit (lib.trivial) id throwIfNot;
    in
    name: subject:
    throwIfNot (isAttrs subject) "Secret '${name}' must have a `tls.subject` attrset." throwIfNot
      (isString subject.country)
      "Secret '${name}' must have a `tls.subject.country` string."
      throwIfNot
      (isString subject.state)
      "Secret '${name}' must have a `tls.subject.state` string."
      throwIfNot
      (isString subject.location)
      "Secret '${name}' must have a `tls.subject.location` string."
      throwIfNot
      (isString subject.organization)
      "Secret '${name}' must have a `tls.subject.organization` string."
      throwIfNot
      (isString subject.organizational-unit)
      "Secret '${name}' must have a `tls.subject.organizational-unit` string."
      id;
in
{
  age.generators = {
    hex = lib.mkForce (
      {
        pkgs,
        secret,
        ...
      }:
      "${pkgs.openssl}/bin/openssl rand -hex ${toString (secret.settings.length or 24)}"
    );

    base64 = lib.mkForce (
      {
        pkgs,
        secret,
        ...
      }:
      ''
        ${pkgs.openssl}/bin/openssl rand --base64 ${toString (secret.settings.length or 32)} | tr -d '\n'
      ''
    );

    base64url = lib.mkForce (
      {
        pkgs,
        secret,
        ...
      }:
      ''
        ${pkgs.openssl}/bin/openssl rand ${
          toString (secret.settings.length or 60)
        } | ${pkgs.coreutils}/bin/basenc --base64url --wrap=0
      ''
    );

    age-identity =
      {
        pkgs,
        file,
        ...
      }:
      ''
        publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        ${pkgs.rage}/bin/rage-keygen 2> "$publicKeyFile"
        ${lib.getExe pkgs.gnused} 's/Public key: //' -i "$publicKeyFile"
      '';

    binary-cache-key =
      {
        pkgs,
        file,
        ...
      }:
      let
        keyName = "${config.networking.fqdn}";
      in
      ''
        publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT
        ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
          ${lib.escapeShellArg keyName} \
          "$tmpdir/private.pem" \
          "$publicKeyFile"
        cat "$tmpdir/private.pem"
      '';

    environment-file =
      {
        decrypt,
        deps,
        secret,
        ...
      }:
      let
        keys = secret.settings.keys;
        pairs = lib.lists.zipListsWith (key: dep: { inherit key dep; }) keys deps;
      in
      lib.strings.concatStringsSep "; " (
        map (
          pair: "echo \"${lib.escapeShellArg pair.key}=$(${decrypt} ${lib.escapeShellArg pair.dep.file})\""
        ) pairs
      );

    htpasswd =
      {
        decrypt,
        deps,
        pkgs,
        secret,
        ...
      }:
      lib.strings.concatMapStrings (
        { file, ... }:
        "printf '%s\\n' \"$(${decrypt} ${lib.escapeShellArg file} "
        + "| ${pkgs.apacheHttpd}/bin/htpasswd -niBC 10 "
        + "${lib.escapeShellArg secret.settings.username})\"; "
      ) deps;

    rfc3986-secret =
      { pkgs, ... }:
      ''
        secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)
        echo "$secret"
      '';

    shared-ssh-key =
      {
        pkgs,
        file,
        name,
        ...
      }:
      ''
        publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        privateKey=$(exec 3>&1; ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${name}"} -f /proc/self/fd/3 <<<y >/dev/null 2>&1; true)
        echo "$privateKey" | ssh-keygen -f /proc/self/fd/0 -y > "$publicKeyFile"
        echo "$privateKey"
      '';

    ssh-key =
      {
        pkgs,
        file,
        name,
        ...
      }:
      let
        target = config.networking.hostName or config.home.username;
      in
      ''
        publicKeyFile=${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        privateKey=$(exec 3>&1; ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${target}:${name}"} -f /proc/self/fd/3 <<<y >/dev/null 2>&1; true)
        echo "$privateKey" | ssh-keygen -f /proc/self/fd/0 -y > "$publicKeyFile"
        echo "$privateKey"
      '';

    tailscale-preauthkey =
      {
        pkgs,
        secret,
        name,
        ...
      }:
      let
        inherit (lib) escapeShellArg;
        inherit (lib.trivial) throwIfNot;
        inherit (lib) isAttrs isString;
        inherit (secret) settings;
        ssh = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new root@${escapeShellArg settings.headscaleHost}";
        jq = "${pkgs.jq}/bin/jq";
        user = escapeShellArg settings.user;
      in
      throwIfNot (isAttrs settings) "Secret '${name}' must have a `settings` attrset." throwIfNot
        (isString settings.headscaleHost)
        "Secret '${name}' is missing a `headscaleHost` string."
        throwIfNot
        (isString settings.user)
        "Secret '${name}' is missing a `user` string."
        ''
          set -euo pipefail

          if ! ${ssh} headscale users list -o json | ${jq} -e --arg u ${user} '.[] | select(.name == $u)' >/dev/null 2>&1; then
            ${ssh} headscale users create ${user} >&2
          fi

          user_id=$(${ssh} headscale users list -o json | ${jq} -r --arg u ${user} '.[] | select(.name == $u) | .id')

          ${ssh} headscale preauthkeys create --user "$user_id" --reusable --expiration 99y
        '';

    template-file =
      {
        decrypt,
        deps,
        pkgs,
        secret,
        ...
      }:
      let
        template = secret.settings.template or (builtins.readFile secret.settings.templateFile);
      in
      ''
        printf '%s' ${lib.escapeShellArg template} \
          ${lib.strings.concatStringsSep " " (
            map (dep: ''
              | ${pkgs.replace}/bin/replace-literal \
                -e \
                -f \
                "%${lib.escapeShellArg dep.name}%" \
                "$(${decrypt} ${lib.escapeShellArg dep.file})" \
            '') deps
          )}
      '';

    timestamp = _: ''
      date +%FT%T%Z
    '';

    tls-ca-root =
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

    tls-signed-certificate =
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
          ${pkgs.openssl}/bin/openssl verify \
            -CAfile $cert_path \
            $out_file \
            1>&2
          cat signing.key
          rm ca.key
          rm san.cnf
          rm signing.{crt,key}
        '';

    wpa-supplicant-config =
      {
        decrypt,
        deps,
        pkgs,
        secret,
        ...
      }:
      let
        networks = secret.settings.networks or { };

        generateNetworkBlock =
          ssid: networkConfig: secretFile:
          let
            pskKey =
              if lib.hasPrefix "ext:" networkConfig.pskRaw then
                lib.removePrefix "ext:" networkConfig.pskRaw
              else
                throw "pskRaw must be in format 'ext:keyname'";

            priority = toString (
              if networkConfig ? priority && networkConfig.priority != null then networkConfig.priority else 1
            );
          in
          ''
            psk_value=$(${decrypt} ${lib.escapeShellArg secretFile} | ${pkgs.gnugrep}/bin/grep -E "^${lib.escapeShellArg pskKey}=" | ${pkgs.coreutils}/bin/cut -d= -f2-)
            printf 'network={\n  ssid="%s"\n  key_mgmt=WPA-PSK WPA-EAP SAE FT-PSK FT-EAP FT-SAE\n  psk="%s"\n  priority=%s\n}\n\n' ${lib.escapeShellArg ssid} "$psk_value" ${lib.escapeShellArg priority}
          '';

        secretFile = (builtins.head deps).file;

        networkBlocks = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (ssid: cfg: generateNetworkBlock ssid cfg secretFile) networks
        );
      in
      ''
        ${networkBlocks}
        printf 'pmf=1\nbgscan="simple:30:-70:3600"\n'
      '';
  };
}
