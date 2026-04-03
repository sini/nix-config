{ den, ... }:
{
  den = {
    default.includes = [
      # ${user}._.${host} and ${host}._.${user}
      den._.mutual-provider
      # Provides flake-parts inputs' (system-specialized inputs) as a module argument
      den._.inputs'
      # Provides flake-parts self' (system-specialized self) as a module argument
      den._.self'
    ];

    # Global host-level includes (apply to all den hosts)
    ctx.host.includes = [
      den._.hostname
    ];

    # Global user-level includes (apply to all den users)
    ctx.user.includes = [
      den._.define-user
    ];
  };
}
