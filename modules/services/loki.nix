# { rootPath, ... }:
{
  flake.features.loki.nixos =
    { config, ... }:
    {
      services = {
        loki = {
          enable = true;
          configuration = {
            server = {
              http_listen_address = "0.0.0.0";
              http_listen_port = 3100;
              grpc_listen_address = "0.0.0.0";
              grpc_listen_port = 9095;
            };

            auth_enabled = false;

            ingester = {
              lifecycler = {
                address = "127.0.0.1";
                ring = {
                  kvstore = {
                    store = "inmemory";
                  };
                  replication_factor = 1;
                };
                final_sleep = "0s";
              };
              chunk_idle_period = "1h";
              max_chunk_age = "1h";
              chunk_target_size = 1048576;
              chunk_retain_period = "30s";
            };

            schema_config = {
              configs = [
                {
                  from = "2020-10-24";
                  store = "boltdb-shipper";
                  object_store = "filesystem";
                  schema = "v11";
                  index = {
                    prefix = "index_";
                    period = "24h";
                  };
                }
              ];
            };

            storage_config = {
              boltdb_shipper = {
                active_index_directory = "/var/lib/loki/boltdb-shipper-active";
                cache_location = "/var/lib/loki/boltdb-shipper-cache";
                cache_ttl = "24h";
              };
              filesystem = {
                directory = "/var/lib/loki/chunks";
              };
            };

            limits_config = {
              reject_old_samples = true;
              reject_old_samples_max_age = "168h";
              retention_period = "30d";
              allow_structured_metadata = false;
            };

            # chunk_store_config is deprecated and removed

            table_manager = {
              retention_deletes_enabled = true;
              retention_period = "30d";
            };

            compactor = {
              working_directory = "/var/lib/loki/compactor";
              compaction_interval = "10m";
              retention_enabled = true;
              retention_delete_delay = "2h";
              retention_delete_worker_count = 150;
              delete_request_store = "filesystem";
            };
          };
        };

        nginx.virtualHosts = {
          "loki.${config.networking.domain}" = {
            forceSSL = true;
            useACMEHost = config.networking.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:3100";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        };
      };

      # Open firewall for Loki ingestion from other nodes
      networking.firewall.allowedTCPPorts = [
        3100
        9095
      ];

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/loki";
          user = "loki";
          group = "loki";
          mode = "0755";
        }
      ];

      # Ensure loki data directories exist with proper permissions
      systemd.tmpfiles.rules = [
        "d /var/lib/loki 0755 loki loki -"
        "d /var/lib/loki/chunks 0755 loki loki -"
        "d /var/lib/loki/boltdb-shipper-active 0755 loki loki -"
        "d /var/lib/loki/boltdb-shipper-cache 0755 loki loki -"
        "d /var/lib/loki/compactor 0755 loki loki -"
      ];
    };
}
