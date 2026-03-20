# Kanidm System Authentication Integration (Future)

## Current State

As of the labels migration, all groups are provisioned to Kanidm including:

- **User-role groups**: Identity groups (admins, users) and login gates
  (system-access, workstation-access, server-access)
- **POSIX groups**: Unix permission groups with gidNumbers (wheel, audio, video,
  podman, etc.)
- **OAuth-grant groups**: Service access groups for OIDC claims

However, **system login still uses local Unix accounts**. Kanidm is only used
for:

1. OAuth2/OIDC authentication for services (Grafana, Forgejo, etc.)
1. Group membership management
1. LDAP exposure (once POSIX attributes are set)

## Goal: Kanidm as Authoritative Identity Provider

Enable system login via Kanidm using PAM/NSS integration, making Kanidm the
single source of truth for all identities.

### Benefits

- ✅ Centralized identity management
- ✅ Consistent user experience across SSH, local login, and services
- ✅ LDAP exposure works for all identities and groups
- ✅ Simplified user provisioning (manage in Kanidm, auto-sync to hosts)
- ✅ Password reset and MFA managed centrally

---

## Implementation Checklist

### Phase 1: POSIX Attribute Provisioning ⚠️ REQUIRED FIRST

**Status:** Not yet implemented (TODO in provision/users.nix)

POSIX groups currently have `gid` defined but **Kanidm doesn't know about them
yet**. They need POSIX attributes set via CLI:

```bash
kanidm group posix set --name wheel --gidnumber 10
kanidm group posix set --name audio --gidnumber 63
kanidm group posix set --name podman --gidnumber 993
# ... for all 13 POSIX groups
```

**Implementation approaches:**

#### Option A: Extend services.kanidm.provision (Recommended)

Add POSIX group provisioning to the existing Kanidm provision module:

```nix
# In modules/services/kanidm/provision/users.nix or new posix-groups.nix
services.kanidm.provision.posixGroups = lib.filterAttrs
  (_: g: lib.elem "posix" (g.labels or []))
  config.groups;

# Then in the provision script, add:
${lib.concatMapStringsSep "\n" (name:
  let g = config.groups.${name};
  in "kanidm group posix set --name ${name} --gidnumber ${toString g.gid}"
) (lib.attrNames posixGroups)}
```

#### Option B: Custom systemd service

Create a one-shot service that runs after Kanidm startup:

```nix
systemd.services.kanidm-posix-setup = {
  description = "Set POSIX attributes for Kanidm groups";
  after = [ "kanidm.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  script = ''
    # Wait for Kanidm to be ready
    until kanidm health; do sleep 1; done

    # Set POSIX attributes
    ${lib.concatMapStringsSep "\n" ...}
  '';
};
```

**Verification:**

```bash
kanidm group posix show --name wheel
# Should return: gidNumber: 10
```

---

### Phase 2: Enable Kanidm PAM/NSS Integration

**NixOS modules to enable:**

```nix
# In a host configuration (e.g., modules/hosts/cortex/host.nix)
{
  security.pam.services = {
    # Enable Kanidm PAM for SSH
    sshd.kanidm = {
      enable = true;
      # Kanidm server URL
      uri = "https://auth.${environment.domain}";
    };

    # Enable for local login (optional, start with SSH only)
    login.kanidm.enable = true;
    su.kanidm.enable = true;
    sudo.kanidm.enable = true;
  };

  # NSS integration for user/group lookups
  system.nss = {
    # Add Kanidm to NSS lookup chain
    # This allows 'id <username>' to resolve Kanidm users
    modules = [ pkgs.kanidm ];
  };

  # Kanidm client configuration
  services.kanidm = {
    clientSettings = {
      uri = "https://auth.${environment.domain}";
      # Optionally verify TLS cert
      verify_ca = true;
      verify_hostnames = true;
    };

    # Unixd daemon (handles PAM/NSS requests)
    unixd = {
      enable = true;
      settings = {
        pam_allowed_login_groups = [
          # Only allow login for users in these groups
          "system-access"
          "workstation-access"  # depending on host role
        ];
        # Home directory creation
        home_prefix = "/home";
        home_attr = "uuid";  # or "name" for /home/<username>
        home_alias = "name";
        # Default shell
        default_shell = "/run/current-system/sw/bin/bash";
      };
    };
  };
}
```

**Gradual rollout strategy:**

1. **Test on non-production workstation** (e.g., cortex in dev environment)
1. **Enable SSH only first** (`sshd.kanidm.enable = true`)
1. **Verify login works** for a test user
1. **Keep local fallback** (don't disable local accounts yet)
1. **Expand to more hosts** once stable
1. **Enable local login** (`login.kanidm.enable = true`) after SSH is proven

---

### Phase 3: User Provisioning to Kanidm

Currently, `services.kanidm.provision.persons` only provisions users who have
oauth-grant or user-role groups. This works for your current setup, but for full
PAM integration, you need:

**Option A: Provision all canonical users**

```nix
# In provision/users.nix
kanidmUsers = users;  # Remove the filter, provision everyone
```

**Option B: Provision based on environment.access**

```nix
# Already done - users in environment.access get provisioned
# This is probably correct: only users with access bindings should exist in Kanidm
```

**POSIX user attributes:** Users also need POSIX attributes set:

```bash
kanidm person posix set --name sini --gidnumber 1000 --shell /bin/bash
kanidm person posix set-loginshell --name sini --shell /bin/bash
```

Add to provision script:

```nix
${lib.concatMapStringsSep "\n" (username:
  let user = users.${username};
  in lib.optionalString (user.system.uid != null) ''
    kanidm person posix set --name ${username} \
      --gidnumber ${toString user.system.gid} \
      --shell /run/current-system/sw/bin/bash
  ''
) (lib.attrNames kanidmUsers)}
```

---

### Phase 4: SSH Key Management in Kanidm

Users' SSH keys are currently provisioned to `/root/.ssh/authorized_keys` for
root access. With Kanidm PAM, SSH keys should be managed in Kanidm:

```bash
kanidm person ssh add-publickey --name sini "ssh-rsa AAAA..."
```

Add to provision script:

```nix
${lib.concatMapStringsSep "\n" (username:
  let user = users.${username};
  in lib.concatMapStringsSep "\n" (key:
    "kanidm person ssh add-publickey --name ${username} '${key}'"
  ) user.identity.sshKeys
) (lib.attrNames kanidmUsers)}
```

Then Kanidm's PAM module will automatically inject the keys for SSH
authentication.

---

## Verification Steps

### After Phase 1 (POSIX Groups)

```bash
# Check group exists in Kanidm
kanidm group list | grep wheel

# Check POSIX attributes are set
kanidm group posix show --name wheel
# Expected: gidNumber: 10, members: [...]

# Verify LDAP exposure (if LDAP is enabled)
ldapsearch -H ldap://auth.json64.dev -b "dc=json64,dc=dev" "(cn=wheel)"
```

### After Phase 2 (PAM/NSS)

```bash
# Verify NSS lookup works
getent passwd sini
# Expected: sini:x:1000:1000:Jason Bowman:/home/sini:/bin/bash

getent group wheel
# Expected: wheel:x:10:sini,...

# Test SSH login
ssh sini@cortex
# Should authenticate via Kanidm PAM
```

### After Phase 3 (User Provisioning)

```bash
# Check user exists in Kanidm
kanidm person get --name sini

# Check POSIX attributes
kanidm person posix show --name sini
# Expected: uidNumber: 1000, gidNumber: 1000, loginShell: /bin/bash
```

### After Phase 4 (SSH Keys)

```bash
# Check SSH keys are in Kanidm
kanidm person ssh list-publickeys --name sini
# Expected: [list of SSH public keys]

# Test SSH login with key
ssh sini@cortex
# Should use Kanidm-managed key
```

---

## Rollback Plan

If Kanidm PAM fails, you need local fallback:

### Keep local accounts

```nix
# Don't set users.mutableUsers = false yet
# Keep local Unix accounts active during migration
users.users.sini = {
  # ... existing local account config
};
```

### Emergency access

Ensure `root` account always works locally:

```nix
# Never enable Kanidm PAM for root login
security.pam.services.login.kanidm.enable = false;  # for local console
security.pam.services.sshd.allowRootLogin = "prohibit-password";  # keys only
```

Keep a local admin account with sudo:

```nix
users.users.emergency = {
  isNormalUser = true;
  extraGroups = [ "wheel" ];
  hashedPassword = "...";  # offline password
};
```

---

## References

- [Kanidm PAM/NSS Documentation](https://kanidm.com/stable/pam_and_nsswitch.html)
- [NixOS Kanidm Module Options](https://search.nixos.org/options?query=services.kanidm)
- [Kanidm POSIX Groups](https://kanidm.com/stable/posix_accounts.html)
- [Kanidm SSH Key Management](https://kanidm.com/stable/accounts/ssh_key_dist.html)

---

## Notes

- This integration is **OPTIONAL** for now — you can run indefinitely with local
  Unix accounts + Kanidm OAuth
- POSIX attribute provisioning (Phase 1) is **REQUIRED** even without PAM/NSS,
  for proper LDAP exposure
- Start with a single test host in dev environment
- Keep local fallback for at least 6 months after enabling PAM
- Consider MFA (TOTP/WebAuthn) once PAM is stable — Kanidm supports it natively
