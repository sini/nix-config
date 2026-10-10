# Standalone NixOS module providing custom agenix-rekey secret generators.
# Imported by both the den agenix-generators aspect (for host builds) and
# the nixidy assembly (for kubernetes secret generation).
#
# This file is NOT a flake-parts module — it's a plain NixOS module.
# Underscore prefix prevents import-tree from auto-importing it.
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

  # Shared body of the x509-* generators: an ECDSA P-256 key and a certificate
  # carrying exactly the extensions in `ext`, built in a private tmpdir. With a
  # `ca` dep it is signed by that dep's key (decrypted into the tmpdir only) and
  # verified against `root` before anything is printed; without one it is
  # self-signed. Writes `chain` (cert first, then the issuer chain) to the .crt
  # sidecar and prints only the key.
  x509-cert =
    {
      pkgs,
      decrypt,
      file,
      name,
      secret,
      days,
      ext,
      ca ? null,
      root ? null,
      chain ? false,
      ...
    }:
    let
      openssl = "${pkgs.openssl}/bin/openssl";
      crtOf = f: lib.escapeShellArg (lib.removeSuffix ".age" f + ".crt");
      cnf = ''
        [req]
        distinguished_name = dn
        prompt = no
        [dn]
        CN = ${secret.settings.cn or name}
        [ext]
        ${lib.concatStringsSep "\n" ext}
      '';
      days' = toString (secret.settings.days or days);
    in
    ''
      set -euo pipefail
      umask 077
      tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
      printf '%s' ${lib.escapeShellArg cnf} > "$tmp/cnf"
    ''
    + (
      if ca == null then
        ''
          ${openssl} req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -sha256 \
            -days ${days'} -config "$tmp/cnf" -extensions ext \
            -keyout "$tmp/key.pem" -out "$tmp/cert.pem" >&2
          cp "$tmp/cert.pem" "$tmp/chain.pem"
        ''
      else
        ''
          ${decrypt} ${lib.escapeShellArg ca.file} > "$tmp/ca.key"
          ${openssl} req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -sha256 \
            -config "$tmp/cnf" -keyout "$tmp/key.pem" -out "$tmp/csr.pem" >&2
          ${openssl} x509 -req -sha256 -in "$tmp/csr.pem" \
            -CA ${crtOf ca.file} -CAkey "$tmp/ca.key" -set_serial "0x$(${openssl} rand -hex 16)" \
            -days ${days'} -extfile "$tmp/cnf" -extensions ext -out "$tmp/cert.pem" >&2
          ${openssl} verify -x509_strict -CAfile ${crtOf root.file} \
            ${lib.optionalString (ca != root) "-untrusted ${crtOf ca.file}"} "$tmp/cert.pem" >&2
          cat "$tmp/cert.pem" ${lib.optionalString chain (crtOf ca.file)} > "$tmp/chain.pem"
        ''
    )
    + ''
      cp "$tmp/chain.pem" ${crtOf file}
      cat "$tmp/key.pem"
    '';

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

    # 32-char lowercase hex (16 random bytes) — Servarr-style API keys.
    hex-secret =
      { pkgs, ... }:
      "${pkgs.openssl}/bin/openssl rand -hex 16";

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

    # Syncthing device identity. `generate` writes cert.pem/key.pem; `device-id`
    # derives the (public, non-secret) device id from the cert. Commit the public
    # .crt/.id sidecars; encrypt only key.pem. Strip device-id's trailing newline
    # so the .id is exactly the id (consumers read it raw).
    syncthing-identity =
      {
        pkgs,
        file,
        ...
      }:
      ''
        set -euo pipefail
        tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
        ${pkgs.syncthing}/bin/syncthing generate --home="$tmp" >/dev/null
        base=${lib.escapeShellArg (lib.removeSuffix ".age" file)}
        cp "$tmp/cert.pem" "$base.crt"
        ${pkgs.syncthing}/bin/syncthing --home="$tmp" device-id | tr -d '\n' > "$base.id"
        cat "$tmp/key.pem"
      '';

    # xmsg federation node identity: an ed25519 key and a self-signed cert for
    # pinning (xmsg-federation-design.md §2.2). Commit the public .crt sidecar;
    # encrypt only the key. settings.node names the node (CN), settings.san its
    # DNS name.
    xmsg-identity =
      {
        pkgs,
        file,
        secret,
        ...
      }:
      ''
        set -euo pipefail
        tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
        ${pkgs.openssl}/bin/openssl req -x509 -newkey ed25519 -nodes -days 36500 \
          -subj ${lib.escapeShellArg "/CN=${secret.settings.node}"} \
          -addext ${lib.escapeShellArg "subjectAltName=DNS:${secret.settings.san}"} \
          -keyout "$tmp/key.pem" \
          -out ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".crt")} >&2
        cat "$tmp/key.pem"
      '';

    # xmsg federation CA (federation plan §6.7). The root signs only the
    # intermediates; settings.days sets validity, settings.cn the subject CN.
    # Each writes its public .crt sidecar beside the .age; commit those.
    x509-ca-root =
      args:
      x509-cert (
        args
        // {
          days = 7300;
          ext = [
            "basicConstraints = critical,CA:TRUE"
            "keyUsage = critical,keyCertSign,cRLSign"
            "subjectKeyIdentifier = hash"
          ];
        }
      );

    # deps = [ root ].
    x509-ca-intermediate =
      args@{ deps, ... }:
      x509-cert (
        args
        // {
          days = 1825;
          ca = builtins.elemAt deps 0;
          root = builtins.elemAt deps 0;
          ext = [
            "basicConstraints = critical,CA:TRUE,pathlen:0"
            "keyUsage = critical,keyCertSign,cRLSign"
            "subjectKeyIdentifier = hash"
            "authorityKeyIdentifier = keyid:always"
          ];
        }
      );

    # deps = [ intermediate root ]; the root is read for its .crt only. Exactly one
    # SAN, the URI settings.uri (xmsg X16). The .crt is leaf then intermediate.
    x509-spiffe-leaf =
      args@{ deps, secret, ... }:
      x509-cert (
        args
        // {
          days = 365;
          ca = builtins.elemAt deps 0;
          root = builtins.elemAt deps 1;
          chain = true;
          ext = [
            "basicConstraints = critical,CA:FALSE"
            "keyUsage = critical,digitalSignature"
            "extendedKeyUsage = serverAuth,clientAuth"
            "subjectAltName = URI:${secret.settings.uri}"
            "subjectKeyIdentifier = hash"
            "authorityKeyIdentifier = keyid:always"
          ];
        }
      );

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

    # Docker/podman auth.json content derived from a registry-password
    # dependency: encodes `username:password` as the base64 `auth` token keyed
    # by the registry domain. Mirrors `htpasswd` (single password dep, username
    # from settings); emitted via jq so the JSON stays well-formed regardless of
    # the password's contents.
    container-auth =
      {
        decrypt,
        deps,
        pkgs,
        secret,
        ...
      }:
      let
        dep = builtins.head deps;
        inherit (secret.settings) username registry;
      in
      ''
        auth=$(printf '%s:%s' ${lib.escapeShellArg username} "$(${decrypt} ${lib.escapeShellArg dep.file})" | ${pkgs.coreutils}/bin/base64 -w0)
        ${pkgs.jq}/bin/jq -cn --arg reg ${lib.escapeShellArg registry} --arg auth "$auth" '{auths: {($reg): {auth: $auth}}}'
      '';

    # PKCS#8 ed25519 private key in PEM form — byte-compatible with what helm's
    # `genPrivateKey "ed25519"` emits, so it can replace a chart-minted signing
    # key with one this repo owns.
    ed25519-private-key =
      { pkgs, ... }:
      "${pkgs.openssl}/bin/openssl genpkey -algorithm ed25519";

    # Synapse signing key: one line `ed25519 <key-id> <unpadded base64 32-byte seed>`,
    # the format `generate_signing_key` writes. The key id is `a_` + 4 hex chars.
    synapse-signing-key =
      { pkgs, ... }:
      ''
        printf 'ed25519 a_%s %s\n' \
          "$(${pkgs.openssl}/bin/openssl rand -hex 2)" \
          "$(${pkgs.openssl}/bin/openssl rand 32 | ${pkgs.coreutils}/bin/base64 -w0 | tr -d '=')"
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

    # An access token for a non-admin Synapse user, registered inside the
    # Synapse pod (_synapse-register.py) so registration_shared_secret is read
    # there and never leaves the cluster. Uses the caller's kubeconfig. Only
    # the token is printed; an existing user is an error, since its token is
    # unrecoverable.
    synapse-bot-token =
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
      in
      throwIfNot (isAttrs settings) "Secret '${name}' must have a `settings` attrset." throwIfNot
        (isString settings.namespace)
        "Secret '${name}' is missing a `namespace` string."
        throwIfNot
        (isString settings.workload)
        "Secret '${name}' is missing a `workload` string (e.g. deploy/synapse)."
        throwIfNot
        (isString settings.user)
        "Secret '${name}' is missing a `user` string."
        throwIfNot
        (isString settings.secretsFile)
        "Secret '${name}' is missing a `secretsFile` string (Synapse's secrets YAML in the pod)."
        ''
          set -euo pipefail
          ${pkgs.kubectl}/bin/kubectl -n ${escapeShellArg settings.namespace} \
            exec -i ${escapeShellArg settings.workload} -- \
            python3 - ${escapeShellArg settings.user} ${escapeShellArg settings.secretsFile} \
            < ${./_synapse-register.py}
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
