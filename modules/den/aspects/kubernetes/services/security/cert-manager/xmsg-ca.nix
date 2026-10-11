# xmsg cluster CA (federation plan §6.7): a CA ClusterIssuer backed by the
# cluster intermediate that applications/dev/ai/mcp/xmsg.nix declares under
# .secrets/xmsg-ca, issuing pod certificates whose one URI SAN is
# spiffe://json64.dev/ns/<ns>/sa/<sa>.
#
# The issuer Secret's tls.crt is the intermediate then the root, so an issued
# tls.crt is leaf, intermediate, root and verifies against the root alone (what
# xmsg peers trust). The key reaches the cluster on the agenix -> sops path.
#
# Which identities a namespace may request is enforced at admission by a
# ValidatingAdmissionPolicy, not approver-policy: approver-policy is not in the
# chart set, while VAP is built into the apiserver. A Certificate naming this
# issuer must carry exactly one URI SAN in its own namespace and nothing else
# (no other SAN, no CN, not a CA, EKU serverAuth+clientAuth); a
# CertificateRequest naming it is admitted only from cert-manager's controller,
# so every request comes from a Certificate the policy admitted. cert-manager's
# built-in approver then approves as usual.
{ lib, rootPath, ... }:
let
  issuer = "xmsg-cluster-ca";
  caDir = rootPath + "/.secrets/xmsg-ca";
  rootCrt = caDir + "/root.crt";
  intermediateCrt = caDir + "/cluster-intermediate.crt";
  controller = "system:serviceaccount:cert-manager:cert-manager";

  # Enabled, and refused by name until the CA's public sidecars are committed.
  enabledFor =
    cluster:
    let
      on = cluster.settings.kubernetes.services.security.cert-manager.xmsg-ca.enable;
      absent = lib.filter (f: !builtins.pathExists f) [
        rootCrt
        intermediateCrt
      ];
    in
    if on && absent != [ ] then
      throw ''
        xmsg cluster CA: ${lib.concatMapStringsSep ", " toString absent} absent. Set
        settings.applications.dev.ai.mcp.xmsg.federation.ca.enable on a fedPair host, run
        `agenix generate`, `git add` the .age and .crt files, then `agenix sops-rekey`.
      ''
    else
      on;

  noneOf =
    fields:
    lib.concatMapStringsSep " && " (
      f: "(!has(object.spec.${f}) || size(object.spec.${f}) == 0)"
    ) fields;
in
{
  den.aspects.kubernetes.services.security.cert-manager.xmsg-ca = {
    settings.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Render the xmsg-cluster-ca ClusterIssuer, its Secret and the admission policy restricting it. Needs the CA under .secrets/xmsg-ca (xmsg federation.ca.enable, then `agenix generate`).";
    };

    age-secrets =
      { cluster, ... }:
      {
        age.secrets = lib.optionalAttrs (enabledFor cluster) {
          xmsg-cluster-ca-key = {
            # Generated host-side (an intermediary secret); no generator here.
            rekeyFile = caDir + "/cluster-intermediate.age";
            sopsOutput = {
              file = "cert-manager";
              key = "xmsg-cluster-ca-key";
            };
          };
        };
      };

    k8s-manifests =
      { config, cluster, ... }:
      lib.optionalAttrs (enabledFor cluster) {
        applications.cert-manager.resources = {
          secrets.${issuer} = {
            type = "kubernetes.io/tls";
            stringData = {
              "tls.crt" = builtins.readFile intermediateCrt + builtins.readFile rootCrt;
              "tls.key" = config.age.secrets.xmsg-cluster-ca-key.sopsRef;
              "ca.crt" = builtins.readFile rootCrt;
            };
          };

          clusterIssuers.${issuer}.spec.ca.secretName = issuer;

          validatingAdmissionPolicies.${issuer}.spec = {
            failurePolicy = "Fail";
            matchConstraints.resourceRules = [
              {
                apiGroups = [ "cert-manager.io" ];
                apiVersions = [ "*" ];
                operations = [
                  "CREATE"
                  "UPDATE"
                ];
                resources = [
                  "certificates"
                  "certificaterequests"
                ];
              }
            ];
            matchConditions = [
              {
                name = "names-${issuer}";
                expression = ''
                  object.spec.issuerRef.name == '${issuer}' &&
                  has(object.spec.issuerRef.kind) && object.spec.issuerRef.kind == 'ClusterIssuer' &&
                  (!has(object.spec.issuerRef.group) || object.spec.issuerRef.group in ["", 'cert-manager.io'])
                '';
              }
            ];
            validations = [
              {
                expression = "request.resource.resource != 'certificaterequests' || request.userInfo.username == '${controller}'";
                message = "only cert-manager's controller may request from ${issuer}; create a Certificate";
              }
              {
                expression = ''
                  request.resource.resource != 'certificates' ||
                  (has(object.spec.uris) && size(object.spec.uris) == 1 &&
                   object.spec.uris[0].matches('^spiffe://json64[.]dev/ns/' + request.namespace + '/sa/[a-z0-9]([-.a-z0-9]*[a-z0-9])?$'))
                '';
                message = "a ${issuer} certificate carries exactly one URI SAN, spiffe://json64.dev/ns/<its namespace>/sa/<sa>";
              }
              {
                expression = ''
                  request.resource.resource != 'certificates' ||
                  (${
                    noneOf [
                      "dnsNames"
                      "ipAddresses"
                      "emailAddresses"
                      "otherNames"
                      "commonName"
                    ]
                  } &&
                   !has(object.spec.literalSubject) && !(has(object.spec.isCA) && object.spec.isCA))
                '';
                message = "a ${issuer} certificate has no other SAN, no common name or literal subject, and is not a CA";
              }
              {
                expression = ''
                  request.resource.resource != 'certificates' ||
                  (has(object.spec.usages) && 'server auth' in object.spec.usages && 'client auth' in object.spec.usages &&
                   object.spec.usages.all(u, u in ['digital signature', 'key encipherment', 'server auth', 'client auth']))
                '';
                message = "a ${issuer} certificate's usages are server auth and client auth (plus digital signature or key encipherment)";
              }
            ];
          };

          validatingAdmissionPolicyBindings.${issuer}.spec = {
            policyName = issuer;
            validationActions = [ "Deny" ];
          };
        };
      };
  };
}
