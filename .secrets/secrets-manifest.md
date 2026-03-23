# Agenix Secrets Manifest

Generated on: 26.05
Total unique secrets: 55
- Generated: 47
- Manually set: 8

---

## Manually Set Secrets

These secrets must be manually created and encrypted. They are stored in the repository
and rekeyed for each host.

### global-cloudflare-api-key
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/prod/cloudflare-api-key.age`




### json64-dev-cloudflare-api-key
- **Used by**: nixos:bitstream
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/dev/cloudflare-api-key.age`




### json64-dev-cloudflare-api-key
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/prod/cloudflare-api-key.age`




### spotify-player-credentials
- **Used by**: 
  - home:sini@blade
  - home:sini@cortex
- **Owner**: root:root (640)
- **Rekey File**: `.secrets/users/sini/spotify-player-credentials.age`




### user-shuo-password
- **Used by**: 
  - nixos:blade
  - nixos:cortex
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/users/shuo/hashed-password.age`




### user-sini-password
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:blade
  - nixos:cortex
  - nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/users/sini/hashed-password.age`




### user-will-password
- **Used by**: 
  - nixos:blade
  - nixos:cortex
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/users/will/hashed-password.age`




### wpa-supplicant
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/dev/wpa_supplicant-arcade.age`





---

## Generated Secrets

These secrets are automatically generated using agenix-rekey's generator functionality.
They will be created automatically if they don't exist.

### argocd-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/argocd-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### attic-server-env
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/generated/attic-server-env.age`
- **Generator**: built-in: environment-file
- **Has Dependencies**: Yes


### attic-server-token
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/prod/attic/server-token.age`
- **Generator**: custom-script

- **Intermediary**: Yes (not exposed to services)

### forgejo-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/forgejo-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### grafana-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/grafana-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### grafana-oidc-secret
- **Used by**: nixos:uplink
- **Owner**: grafana:grafana (0400)
- **Rekey File**: `.secrets/env/prod/oidc/grafana-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### grafana-secret-key
- **Used by**: nixos:uplink
- **Owner**: grafana:grafana (0400)
- **Rekey File**: `.secrets/env/prod/grafana-secret-key.age`
- **Generator**: built-in: hex



### headscale-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/headscale-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### headscale-oidc-secret
- **Used by**: nixos:uplink
- **Owner**: headscale:headscale (440)
- **Rekey File**: `.secrets/env/prod/oidc/headscale-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### hubble-ui-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/hubble-ui-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### initrd_host_ed25519_key
- **Used by**: nixos:axon-01
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-01/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:axon-02
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-02/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:axon-03
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-03/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:bitstream
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/bitstream/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/blade/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:cortex
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/cortex/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### initrd_host_ed25519_key
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/generated/initrd_host_ed25519_key.age`
- **Generator**: built-in: ssh-key



### jellyfin-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/jellyfin-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### kanidm-admin-password
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/kanidm-admin-password.age`
- **Generator**: built-in: passphrase



### kubernetes-cluster-token
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/clusters/axon/cluster-token.age`
- **Generator**: built-in: passphrase



### longhorn-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/longhorn-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### nix-remote-build-user-key
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:blade
  - nixos:cortex
  - nixos:uplink
  - darwin:patch
- **Owner**: 0:0 (600)
- **Rekey File**: `.secrets/users/nix-remote-build/id_ed25519.age`
- **Generator**: built-in: shared-ssh-key



### nix_store_signing_key
- **Used by**: nixos:axon-01
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-01/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:axon-02
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-02/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:axon-03
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-03/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:bitstream
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/bitstream/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:cortex
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/cortex/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:uplink
- **Owner**: nix-serve:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### oauth2-proxy-cookie-secret
- **Used by**: nixos:uplink
- **Owner**: oauth2-proxy:oauth2-proxy (440)
- **Rekey File**: `.secrets/env/prod/oauth2-proxy-cookie-secret.age`
- **Generator**: built-in: base64



### oauth2-proxy-keys
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/generated/oauth2-proxy-keys.age`
- **Generator**: built-in: environment-file
- **Has Dependencies**: Yes


### oauth2-proxy-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/oauth2-proxy-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### oauth2-proxy-oidc-secret
- **Used by**: nixos:uplink
- **Owner**: oauth2-proxy:oauth2-proxy (440)
- **Rekey File**: `.secrets/env/prod/oidc/oauth2-proxy-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### open-webui-env
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/generated/open-webui-env.age`
- **Generator**: built-in: environment-file
- **Has Dependencies**: Yes


### open-webui-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/open-webui-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### open-webui-oidc-secret
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/prod/oidc/open-webui-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret

- **Intermediary**: Yes (not exposed to services)

### tailscale-auth-key
- **Used by**: nixos:axon-01
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-01/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:axon-02
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-02/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:axon-03
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/axon-03/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:bitstream
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/bitstream/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/blade/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:cortex
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/cortex/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: darwin:patch
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/patch/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### tailscale-auth-key
- **Used by**: nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/uplink/tailscale-preauthkey.age`
- **Generator**: built-in: tailscale-preauthkey



### user-identity-shuo
- **Used by**: 
  - nixos:blade
  - nixos:cortex
- **Owner**: shuo:shuo (600)
- **Rekey File**: `.secrets/users/shuo/id_agenix.age`
- **Generator**: built-in: age-identity



### user-identity-sini
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:blade
  - nixos:cortex
  - nixos:uplink
  - darwin:patch
- **Owner**: sini:sini (600)
- **Rekey File**: `.secrets/users/sini/id_agenix.age`
- **Generator**: built-in: age-identity



### user-identity-will
- **Used by**: 
  - nixos:blade
  - nixos:cortex
- **Owner**: will:will (600)
- **Rekey File**: `.secrets/users/will/id_agenix.age`
- **Generator**: built-in: age-identity



### wpa-supplicant-initrd
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/blade/wpa_supplicant_initrd.age`
- **Generator**: built-in: wpa-supplicant-config
- **Has Dependencies**: Yes



---

## Secret File Organization

### User Secrets
- Location: `.secrets/users/<username>/`
- Types: hashed passwords, age identities

### Environment Secrets
- Location: `.secrets/env/<environment>/`
- Types: OIDC credentials, API keys, cluster tokens

### Service Secrets
- Location: `.secrets/services/<service>/`
- Types: certificates, API keys, service-specific credentials

---

## Master Identities

Secrets can be decrypted using any of these master keys:
- `.secrets/pub/master.pub`
- `.secrets/pub/master-clone1.pub`
- `.secrets/pub/master-clone2.pub`
