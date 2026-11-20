# The gen-status publisher's credentials on a host where den-ag-design publishes
# (docs/static-sites-to-garage.md). This host becomes a recipient of the same two
# age secrets the cluster's gen-status GarageKey imports
# (kubernetes/services/web/static-sites.nix), and gets them as one env file,
# readable only by the system owner:
#
#   /run/agenix/gen-status-publish.env
#     AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION=garage,
#     GEN_STATUS_S3_ENDPOINT=https://s3.<domain>, GEN_STATUS_BUCKET
#
# den-ag-design's `publish-gen-status` sources it and runs `aws s3 sync`. The key
# can write only the gen-status bucket.
{ den, rootPath, ... }:
let
  # The cluster and its secrets are the prod environment's, whatever this host's.
  prodEnv = den.environments.prod;
  prod = rootPath + "/.secrets/env/prod/gen-status-publisher";
in
{
  den.aspects.services.web.gen-status-publisher = {
    age-secrets =
      { config, host, ... }:
      {
        age.secrets = {
          # The same rekeyFiles and generators as the cluster's, so agenix-rekey
          # gives this host the same values.
          gen-status-publisher-key-id = {
            rekeyFile = prod + "/key-id.age";
            generator.script = "garage-key-id";
          };
          gen-status-publisher-secret-key = {
            rekeyFile = prod + "/secret-key.age";
            generator.script = "garage-secret-key";
          };
          gen-status-publish-env = {
            rekeyFile = host.secretPath + "/gen-status-publish-env.age";
            generator.dependencies = [
              config.age.secrets.gen-status-publisher-key-id
              config.age.secrets.gen-status-publisher-secret-key
            ];
            generator.script = "template-file";
            settings.template = ''
              AWS_ACCESS_KEY_ID=%gen-status-publisher-key-id%
              AWS_SECRET_ACCESS_KEY=%gen-status-publisher-secret-key%
              AWS_DEFAULT_REGION=garage
              GEN_STATUS_S3_ENDPOINT=https://${prodEnv.getDomainFor "garage-s3"}
              GEN_STATUS_BUCKET=${prodEnv.getDomainFor "gen-status"}
            '';
            path = "/run/agenix/gen-status-publish.env";
            owner = host.system-owner;
            mode = "0400";
          };
        };
      };
  };
}
