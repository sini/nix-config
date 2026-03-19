{
  # Identity-only users (Kanidm/SSO — no Unix accounts)
  # Group memberships are defined in environments/<env>/users.nix via access bindings
  users = {
    json = { };

    json_user = {
      identity = {
        displayName = "Jason-user";
        email = "jason_user@json64.dev";
      };
    };

    greco = { };

    taiche = {
      identity.displayName = "Chris";
    };

    jennism = {
      identity.displayName = "Jennifer";
    };

    hugs = {
      identity.displayName = "Shawn";
    };

    ellen = { };

    jenn = {
      identity.displayName = "Jennifer";
    };

    tyr = { };
    zogger = { };
    jess = { };
    leo = { };
    vincentpierre = { };

    you = {
      identity.displayName = "You";
    };

    yiran = {
      identity.displayName = "Yiran";
    };

    louisabella = { };
  };
}
