{
  flake.features.kanidm.nixos =
    { environment, ... }:
    {
      services.kanidm.provision = {
        groups = {
          "admins" = { };
          "users".members = [ "admins" ];
        };

        persons = {
          json = {
            displayName = "Jason";
            mailAddresses = [ "jason@${environment.email.domain}" ];
            groups = [ "admins" ];
          };
          json_user = {
            displayName = "Jason-user";
            mailAddresses = [ "jason_user@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          shuo = {
            displayName = "Shuo";
            mailAddresses = [ "shuo@${environment.email.domain}" ];
            groups = [ "admins" ];
          };
          will = {
            displayName = "Will";
            mailAddresses = [ "will@${environment.email.domain}" ];
            groups = [
              "admins"
              "users"
              "grafana.server-admins"
              "open-webui.access"
            ];
          };
          greco = {
            displayName = "Jason";
            mailAddresses = [ "greco@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          taiche = {
            displayName = "Chris";
            mailAddresses = [ "taiche@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          jennism = {
            displayName = "Jennifer";
            mailAddresses = [ "jennism@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          hugs = {
            displayName = "Shawn";
            mailAddresses = [ "hugs@${environment.email.domain}" ];
            groups = [
              "users"
              "grafana.server-admins"
            ];
          };
          ellen = {
            displayName = "Ellen";
            mailAddresses = [ "ellen@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          jenn = {
            displayName = "Jennifer";
            mailAddresses = [ "jenn@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          tyr = {
            displayName = "tyr";
            mailAddresses = [ "tyr@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          zogger = {
            displayName = "zogger";
            mailAddresses = [ "zogger@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          jess = {
            displayName = "jess";
            mailAddresses = [ "jess@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          leo = {
            displayName = "leo";
            mailAddresses = [ "leo@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          vincentpierre = {
            displayName = "vincentpierre";
            mailAddresses = [ "vincentpierre@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          you = {
            displayName = "You";
            mailAddresses = [ "you@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          yiran = {
            displayName = "Yiran";
            mailAddresses = [ "yiran@${environment.email.domain}" ];
            groups = [ "users" ];
          };
          louisabella = {
            displayName = "louisabella";
            mailAddresses = [ "louisabella@${environment.email.domain}" ];
            groups = [ "users" ];
          };
        };
      };
    };
}
