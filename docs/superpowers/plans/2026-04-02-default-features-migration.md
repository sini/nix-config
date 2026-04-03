# Default Features Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use
> superpowers-extended-cc:subagent-driven-development (if subagents available)
> or superpowers-extended-cc:executing-plans to implement this plan. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all 29 remaining default features to den aspects, achieving
1:1 parity with the current feature system, and wire them into a
`den.aspects.default` that bitstream includes.

**Architecture:** Each feature becomes a den aspect under
`modules/den/aspects/`. Features using `linux` map to `nixos`, `darwin` to
`darwin`, `system`/`os` to `os`, `home` to `homeManager`, `homeLinux` to
`homeLinux`. Features with `provides.impermanence`/`provides.secrets` become
sub-aspects. Features with `collectsProviders` get custom forwarding classes.
After all aspects exist, `den.aspects.default` includes them all and `bitstream`
includes `default`.

**Tech Stack:** Nix, den, flake-parts, import-tree

**Reference repos:**

- Den source: `/home/sini/Documents/repos/den-configs/den`
- Gwenodai example: `/home/sini/Documents/repos/den-configs/gwenodai-nixos`
- Design spec:
  `docs/superpowers/specs/2026-04-02-default-features-migration-design.md`

**Key patterns:**

- `den.lib.perHost { nixos = ...; }` for system-level config
- `den.lib.perUser { homeManager = ...; }` for user-level config
- Sub-aspects grouped under `_ = { ... }` (single key, satisfies statix)
- Forwarding classes: `{ class, aspect-chain }: den._.forward { ... }` in
  `den.ctx.default.includes`
- Features accessing `host`, `environment`, `users`, `settings` use function
  args in the class module

**Important context variables available in den aspect modules:**

- In `nixos`/`darwin` modules: `{ config, lib, pkgs, inputs, ... }` (standard
  NixOS module args)
- Host data: accessed via den.lib.perHost `{ host }` wrapper, then
  `host.networking`, `host.hostname`, etc.
- Environment data: `host.environment` (resolved environment attrset)
- The current feature system injects `host`, `environment`, `users`, `settings`,
  `secrets`, `flakeLib` as special args. In den, `host` comes from perHost,
  others need adaptation.

---

### Task 0: Trivial features (9 features)

**Goal:** Migrate avahi, disko, facter, i18n, power-mgmt, shell, ssd,
stateVersion, time.

**Files:**

- Create: `modules/den/aspects/core/avahi.nix`
- Create: `modules/den/aspects/core/disko.nix`
- Create: `modules/den/aspects/core/facter.nix`
- Create: `modules/den/aspects/core/i18n.nix`
- Create: `modules/den/aspects/core/power-mgmt.nix`
- Create: `modules/den/aspects/core/shell-enable.nix`
- Create: `modules/den/aspects/core/ssd.nix`
- Create: `modules/den/aspects/core/stateVersion.nix`
- Create: `modules/den/aspects/core/time.nix`

**Acceptance Criteria:**

- [ ] Each aspect defines equivalent config to the source feature
- [ ] `nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`
      succeeds
- [ ] No statix or treefmt errors

**Verify:**
`nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`

**Steps:**

- [ ] **Step 1: Read each source feature and create the den aspect**

Source → aspect mapping for each:

**avahi** (`core/network/avahi.nix`) — uses `host.networking.interfaces`:

```nix
# modules/den/aspects/core/avahi.nix
{ den, ... }: {
  den.aspects.avahi = den.lib.perHost ({ host }: {
    nixos = {
      services.avahi = {
        enable = true;
        allowInterfaces = builtins.attrNames host.networking.interfaces;
        nssmdns4 = true;
        nssmdns6 = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          hinfo = true;
          userServices = true;
          workstation = true;
        };
        openFirewall = true;
      };
    };
  });
}
```

Note: `host.networking.interfaces` — this references our custom host schema. In
den, the host object carries whatever we defined in `den.hosts`. We'll need to
ensure bitstream's host definition includes networking data. If den's host
schema doesn't carry this, the aspect should read it from the nixos config or we
pass it differently. **The implementer should check if `host.networking` is
available and adapt accordingly — it may need to be added to the den host
definition or read from a different source.**

**disko** (`core/disko/disko.nix`) — just imports a module:

```nix
# modules/den/aspects/core/disko.nix
{ den, inputs, ... }: {
  den.aspects.disko = den.lib.perHost {
    nixos = {
      imports = [ inputs.disko.nixosModules.disko ];
    };
  };
}
```

**facter** (`core/facter/facter.nix`) — uses `host.facts`:

```nix
# modules/den/aspects/core/facter.nix
{ den, inputs, ... }: {
  den.aspects.facter = den.lib.perHost ({ host }: {
    nixos = {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter = {
        reportPath = host.facts;
        detected = {
          dhcp.enable = false;
          graphics.enable = false;
        };
      };
    };
  });
}
```

Note: `host.facts` — this is a custom attribute on our host schema. The
implementer needs to verify this is accessible on den hosts. If not, hardcode
the path or add it to the host definition.

**i18n** (`core/i18n/i18n.nix`):

```nix
# modules/den/aspects/core/i18n.nix
{ den, ... }: {
  den.aspects.i18n = den.lib.perHost {
    nixos = { lib, ... }: {
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };
      console = {
        keyMap = "us";
        font = lib.mkDefault "Lat2-Terminus16";
      };
    };
  };
}
```

**power-mgmt** (`core/power-mgmt/default.nix`):

```nix
# modules/den/aspects/core/power-mgmt.nix
{ den, ... }: {
  den.aspects.power-mgmt = den.lib.perHost {
    nixos.powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
  };
}
```

**shell** (`core/shell/zsh.nix`) — system-level shell enable (distinct from the
full zsh aspect):

```nix
# modules/den/aspects/core/shell-enable.nix
{ den, ... }: {
  den.aspects.shell-enable = den.lib.perHost {
    os.programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    nixos = { pkgs, ... }: {
      users.defaultUserShell = pkgs.zsh;
    };
  };
}
```

Note: The existing `den.aspects.shell` (from zsh.nix) already includes this via
`_.zsh._.systemEnable`. The implementer should check if this duplicates and
either skip this aspect or make `den.aspects.shell` NOT include the system-level
enable (letting `shell-enable` handle it). **Recommendation: skip creating
shell-enable and let the existing den.aspects.shell handle it.**

**ssd** (`core/ssd/default.nix`):

```nix
# modules/den/aspects/core/ssd.nix
{ den, ... }: {
  den.aspects.ssd = den.lib.perHost {
    nixos.services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
```

**stateVersion** (`core/nix/stateVersion.nix`):

```nix
# modules/den/aspects/core/stateVersion.nix
{ den, ... }: {
  den.aspects.stateVersion = den.lib.perHost {
    darwin.system.stateVersion = "6";
    nixos.system.stateVersion = "26.05";
  };
}
```

**time** (`core/time/time.nix`) — uses `environment.timezone`:

```nix
# modules/den/aspects/core/time.nix
{ den, ... }: {
  den.aspects.time = den.lib.perHost ({ host }: {
    os.time.timeZone = (host.environment or {}).timezone or "UTC";
  });
}
```

Note: `host.environment` may not be populated yet in the den host schema. The
implementer should default gracefully.

- [ ] **Step 2: Verify eval and fix statix/treefmt**

```bash
nix eval .#nixosConfigurations.bitstream.config.system.nixos.version
```

- [ ] **Step 3: Commit**

```bash
git add modules/den/aspects/core/
git commit -m "feat(den): migrate trivial default features to aspects"
```

---

### Task 1: Simple features (10 features)

**Goal:** Migrate firmware, home-manager (feature), hosts, linux-kernel,
nixpkgs, openssh, security, sudo, systemd, systemd-boot, utils.

**Files:**

- Create: `modules/den/aspects/core/firmware.nix`
- Create: `modules/den/aspects/core/home-manager-feature.nix`
- Create: `modules/den/aspects/network/hosts.nix`
- Create: `modules/den/aspects/kernel/linux-kernel.nix`
- Create: `modules/den/aspects/nix/nixpkgs.nix`
- Create: `modules/den/aspects/network/openssh.nix`
- Create: `modules/den/aspects/core/security.nix`
- Create: `modules/den/aspects/core/sudo.nix`
- Create: `modules/den/aspects/core/systemd.nix`
- Create: `modules/den/aspects/core/systemd-boot.nix`
- Create: `modules/den/aspects/core/utils.nix`

**Acceptance Criteria:**

- [ ] Each aspect defines equivalent config
- [ ] Features with `provides.impermanence` have sub-aspects
- [ ] Features accessing `host`, `users`, `environment` use `den.lib.perHost`
      with appropriate args
- [ ] No statix or treefmt errors

**Verify:**
`nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`

**Steps:**

- [ ] **Step 1: Read each source feature**

Read these files:

- `modules/core/firmware/default.nix`
- `modules/core/home-manager/default.nix`
- `modules/core/network/hosts.nix`
- `modules/core/linux-kernel.nix`
- `modules/core/nix/nixpkgs/` (all 4 files)
- `modules/core/openssh/openssh.nix`
- `modules/core/security/polkit.nix` + `modules/core/security/tpm.nix`
- `modules/core/sudo/sudo-rs.nix`
- `modules/core/systemd/default.nix`
- `modules/core/boot/systemd-boot.nix`
- `modules/core/utils/utils.nix`

- [ ] **Step 2: Create each aspect**

Key notes for the implementer:

- **firmware**: Has `provides.impermanence` — make it a sub-aspect under `_`
- **home-manager-feature**: The system-level HM setup (extraSpecialArgs,
  sharedModules). This is complex because it injects `inputs`, `environment`,
  `flakeLib`, `host`, `users`. In den, most of these come from the context.
  **For now, create a simplified version** that sets useGlobalPkgs,
  useUserPackages, and stateVersion. The existing `modules/den/home-manager.nix`
  already handles the basics — the implementer should check for overlap and
  extend rather than duplicate.
- **hosts**: Reads `config.hosts` and `config.environments` (flake-level
  config). This depends on the existing host/environment option system. **For
  now, create a stub that sets basic networking.hosts.** Full cross-host
  discovery is deferred to environment context migration.
- **linux-kernel**: Has `settings` — for now, inline the config with defaults
  (server optimization, latest channel).
- **nixpkgs**: 4 files merged into one aspect — allow-unfree, cachy overlays,
  local overlays, darwin warning.
- **openssh**: Has both `linux` and `darwin` — straightforward.
- **security**: Two files (polkit + tpm) — merge into one aspect with
  sub-aspects.
- **sudo**: Uses `users` arg — access via den context or simplify.
- **systemd**: Has `provides.impermanence` — sub-aspect.
- **systemd-boot**: Straightforward.
- **utils**: Has `system` (cross-platform) and `linux` — use `os` + `nixos`.

- [ ] **Step 3: Verify and commit**

```bash
nix eval .#nixosConfigurations.bitstream.config.system.nixos.version
git add modules/den/aspects/
git commit -m "feat(den): migrate simple default features to aspects"
```

---

### Task 2: Moderate features (4 features)

**Goal:** Migrate deterministic-uids, nix, tailscale, users.

**Files:**

- Create: `modules/den/aspects/users/deterministic-uids.nix`
- Create: `modules/den/aspects/nix/nix.nix`
- Create: `modules/den/aspects/network/tailscale.nix`
- Create: `modules/den/aspects/users/users.nix`

**Acceptance Criteria:**

- [ ] deterministic-uids declares NixOS options and assigns IDs
- [ ] nix configures daemon, GC, substituters across platforms
- [ ] tailscale configures service with settings and
      provides.secrets/impermanence as sub-aspects
- [ ] users creates Unix accounts from user data

**Verify:**
`nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`

**Steps:**

- [ ] **Step 1: Read source features**

Read: `modules/core/deterministic-uids/option.nix`,
`modules/core/deterministic-uids/users.nix`, `modules/core/nix/nix.nix`,
`modules/core/network/tailscale.nix`, `modules/core/users/default.nix`

- [ ] **Step 2: Create each aspect**

Key notes:

- **deterministic-uids**: Declares NixOS options (`users.deterministicIds`) and
  assertions. This is a large module (172 lines of option declarations + 73
  lines of ID assignments). Translate directly — the options and config are
  self-contained NixOS module code.
- **nix**: Has `system`, `darwin`, `linux` — map to `os`, `darwin`, `nixos`.
  Cross-platform settings in `os`, platform-specific GC/daemon config in
  `nixos`/`darwin`.
- **tailscale**: Has `settings`, `provides.secrets`, `provides.impermanence`.
  Settings become inline config for now. The `provides.secrets` sub-aspect
  accesses `host`, `environment`, `flakeLib` — these need careful adaptation to
  den context. The secret generator references `host.secretPath` which may not
  be on the den host schema yet. **Create stubs for the secrets/impermanence
  providers if they can't be fully implemented.**
- **users**: Accesses `users` (resolved user data), `secrets`, `rootPath`. This
  is tightly coupled to the current user resolution system. **Create a
  simplified version** that works with den's built-in user system
  (`den._.define-user` / `den._.primary-user`) and defer the full ACL-driven
  user provisioning.

- [ ] **Step 3: Verify and commit**

---

### Task 3: Complex features (3 features)

**Goal:** Migrate agenix, impermanence, networking with their forwarding
classes.

**Files:**

- Create: `modules/den/aspects/secrets/agenix.nix`
- Create: `modules/den/aspects/secrets/impermanence.nix`
- Create: `modules/den/aspects/network/networking.nix`
- Modify: `modules/den/classes/home-platform.nix` (add forwarding classes for
  secrets, impermanence, firewall)

**Acceptance Criteria:**

- [ ] agenix imports agenix modules and configures age.identityPaths, rekey,
      etc.
- [ ] impermanence imports impermanence module and configures /persist and
      /cache
- [ ] networking generates systemd-networkd config from host.networking
- [ ] Forwarding classes collect contributions from active aspects

**Verify:**
`nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`

**Steps:**

- [ ] **Step 1: Read source features**

Read: `modules/core/agenix/agenix.nix`,
`modules/core/impermanence/impermanence.nix`,
`modules/core/network/networking.nix`

Also read gwenodai's persist implementation for forwarding class patterns:

- `/home/sini/Documents/repos/den-configs/gwenodai-nixos/modules/core/persist [HU]/class/classes.nix`

- [ ] **Step 2: Create forwarding classes**

Add to `modules/den/classes/home-platform.nix` (or create new files):

- `secrets-class`: collects `secrets` class from active aspects → merges into
  `age.secrets`
- `impermanence-class`: collects `persist` class → merges into
  `environment.persistence`
- `firewall-class`: collects `firewall` class → merges into
  `networking.firewall`

Follow gwenodai's `mkSystemClass` pattern with `den._.forward`, `guard`, and
`adapterModule` for list dedup.

- [ ] **Step 3: Create each aspect**

Key notes:

- **agenix**: The most complex. Has `linux`, `darwin`, `system`, `home`,
  `collectsProviders = ["secrets"]`. The `system` module accesses `inputs`,
  `config`, `host`, `users`, `lib`, `settings`. The `home` module accesses
  `inputs`, `config`, `osConfig`, `host`, `lib`. **Start with the system-level
  agenix setup** (imports, identityPaths, rekey config) and **defer the secrets
  collection forwarding class** if it proves too complex. Agenix can work
  without collected secrets — individual aspects just won't auto-contribute
  secrets yet.
- **impermanence**: Has `collectsProviders = ["impermanence"]`, `settings`,
  `system`, `linux`, `home`. The gwenodai persist module is the direct reference
  for the forwarding class pattern. **Follow gwenodai closely.** The system
  option `impermanence.ignorePaths` needs to be declared.
- **networking**: 375 lines. Has `collectsProviders = ["firewall"]`, `os`,
  `linux`. The core logic is systemd-networkd config generation from
  `host.networking`. This is self-contained — translate the helpers and config
  generation directly. The firewall forwarding class is simpler than persist —
  it just collects `networking.firewall.*` contributions.

- [ ] **Step 4: Verify and commit**

---

### Task 4: Wire default aspect and update bitstream

**Goal:** Create `den.aspects.default` that includes all migrated features,
update bitstream to use it.

**Files:**

- Create: `modules/den/aspects/default.nix`
- Modify: `modules/den/hosts/bitstream.nix`

**Acceptance Criteria:**

- [ ] `den.aspects.default` includes all 30 features (29 migrated + existing
      shell/zsh)
- [ ] bitstream includes `den.aspects.default` instead of just
      `den.aspects.shell`
- [ ] `nix eval .#nixosConfigurations.bitstream.config.system.nixos.version`
      succeeds
- [ ] `nix eval .#nixosConfigurations.bitstream.config.networking.hostName`
      returns "bitstream"

**Verify:**
`nix eval .#nixosConfigurations.bitstream.config.networking.hostName` →
"bitstream"

**Steps:**

- [ ] **Step 1: Create default aspect**

```nix
# modules/den/aspects/default.nix
{ den, ... }: {
  den.aspects.default = {
    includes = [
      den.aspects.agenix
      den.aspects.avahi
      den.aspects.deterministic-uids
      den.aspects.disko
      den.aspects.facter
      den.aspects.firmware
      # den.aspects.home-manager-feature  # if created, or skip if covered by den/home-manager.nix
      den.aspects.hosts-file
      den.aspects.i18n
      den.aspects.impermanence
      den.aspects.linux-kernel
      den.aspects.networking
      den.aspects.nix-daemon
      den.aspects.nixpkgs
      den.aspects.openssh
      den.aspects.power-mgmt
      den.aspects.security
      den.aspects.shell
      den.aspects.shell-enable  # or skip if shell already covers it
      den.aspects.ssd
      den.aspects.stateVersion
      den.aspects.sudo
      den.aspects.systemd
      den.aspects.systemd-boot
      den.aspects.tailscale
      den.aspects.time
      den.aspects.users-config
      den.aspects.utils
    ];
  };
}
```

The exact names depend on what the implementer chose in Tasks 0-3. Adjust as
needed.

- [ ] **Step 2: Update bitstream**

```nix
den.aspects.bitstream = {
  includes = [
    den.aspects.default
  ];
  nixos = { ... }: {
    # ... hardware config stays
  };
};
```

- [ ] **Step 3: Verify and commit**

```bash
nix eval .#nixosConfigurations.bitstream.config.system.nixos.version
nix eval .#nixosConfigurations.bitstream.config.networking.hostName
git add modules/den/
git commit -m "feat(den): wire default aspect and update bitstream"
```
