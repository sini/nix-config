# Agenix Secrets Manifest

Generated on: 26.11
Total unique secrets: 85
- Generated: 76
- Manually set: 9

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




### kubernetes-sops-age-key
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/clusters/axon/cluster-sops-age-key.age`




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




### wpa-supplicant-keys-for-initrd
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/dev/wpa_supplicant_psks.age`


- **Intermediary**: Yes (not exposed to services)


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

### bazarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/bazarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### coder-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/coder-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### dash-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/dash-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### forgejo-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/forgejo-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### garage-ui-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/garage-ui-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### glance-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/glance-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### grafana-k8s-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/grafana-k8s-oidc-client-secret.age`
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



### komga-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/komga-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### kubernetes-cluster-token
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/clusters/axon/cluster-token.age`
- **Generator**: built-in: passphrase



### lidarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/lidarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### longhorn-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/longhorn-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### nix_store_signing_key
- **Used by**: nixos:axon-01
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/hosts/axon-01/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:axon-02
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/hosts/axon-02/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:axon-03
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/hosts/axon-03/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:bitstream
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/hosts/bitstream/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:cortex
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/hosts/cortex/generated/nix_store_signing_key.age`
- **Generator**: built-in: binary-cache-key



### nix_store_signing_key
- **Used by**: nixos:uplink
- **Owner**: root:root (0400)
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

### profilarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/profilarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### prowlarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/prowlarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### qbittorrent-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/qbittorrent-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### radarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/radarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### registry-auth
- **Used by**: nixos:cortex
- **Owner**: sini:users (0400)
- **Rekey File**: `.secrets/hosts/cortex/registry-auth.age`
- **Generator**: built-in: container-auth
- **Has Dependencies**: Yes


### registry-auth
- **Used by**: nixos:uplink
- **Owner**: sini:users (0400)
- **Rekey File**: `.secrets/hosts/uplink/registry-auth.age`
- **Generator**: built-in: container-auth
- **Has Dependencies**: Yes


### registry-htpasswd
- **Used by**: nixos:uplink
- **Owner**: nginx:nginx (0400)
- **Rekey File**: `.secrets/env/prod/registry/registry-htpasswd.age`
- **Generator**: built-in: htpasswd
- **Has Dependencies**: Yes


### registry-password
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:cortex
  - nixos:uplink
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/env/prod/registry/registry-password.age`
- **Generator**: built-in: rfc3986-secret



### romm-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/romm-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### sabnzbd-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/sabnzbd-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### shoko-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/shoko-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### sonarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/sonarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### syncthing-hub-identity
- **Used by**: nixos:uplink
- **Owner**: syncthing:syncthing (0400)
- **Rekey File**: `.secrets/hosts/uplink/syncthing-uplink.age`
- **Generator**: built-in: syncthing-identity



### syncthing-identity
- **Used by**: home:sini@blade
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/users/sini/syncthing-blade.age`
- **Generator**: built-in: syncthing-identity



### syncthing-identity
- **Used by**: home:sini@cortex
- **Owner**: root:root (0400)
- **Rekey File**: `.secrets/users/sini/syncthing-cortex.age`
- **Generator**: built-in: syncthing-identity



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



### tdarr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/tdarr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### user-identity-dvicory
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:uplink
- **Owner**: dvicory:dvicory (600)
- **Rekey File**: `.secrets/users/dvicory/id_agenix.age`
- **Generator**: built-in: age-identity



### user-identity-pol
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:uplink
- **Owner**: pol:pol (600)
- **Rekey File**: `.secrets/users/pol/id_agenix.age`
- **Generator**: built-in: age-identity



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



### user-identity-theutz
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:uplink
- **Owner**: theutz:theutz (600)
- **Rekey File**: `.secrets/users/theutz/id_agenix.age`
- **Generator**: built-in: age-identity



### user-identity-vic
- **Used by**: 
  - nixos:axon-01
  - nixos:axon-02
  - nixos:axon-03
  - nixos:bitstream
  - nixos:blade
  - nixos:cortex
  - nixos:uplink
- **Owner**: vic:vic (600)
- **Rekey File**: `.secrets/users/vic/id_agenix.age`
- **Generator**: built-in: age-identity



### user-identity-will
- **Used by**: 
  - nixos:blade
  - nixos:cortex
- **Owner**: will:will (600)
- **Rekey File**: `.secrets/users/will/id_agenix.age`
- **Generator**: built-in: age-identity



### user-signing-key
- **Used by**: 
  - home:sini@blade
  - home:sini@cortex
- **Owner**: root:root (600)
- **Rekey File**: `.secrets/users/sini/id_signing.age`
- **Generator**: built-in: shared-ssh-key



### whisparr-oidc-client-secret
- **Used by**: nixos:uplink
- **Owner**: kanidm:kanidm (0400)
- **Rekey File**: `.secrets/env/prod/oidc/whisparr-oidc-client-secret.age`
- **Generator**: built-in: rfc3986-secret



### wpa-supplicant-initrd
- **Used by**: nixos:blade
- **Owner**: 0:0 (0400)
- **Rekey File**: `.secrets/hosts/blade/generated/wpa-supplicant-initrd.age`
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
