# This file was generated with nixidy resource generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:

with lib;

let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList =
    values:
    if values != null then
      sort (
        a: b:
        if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b) then
          a._priority < b._priority
        else
          false
      ) (mapAttrsToList (n: v: v) values)
    else
      values;

  getDefaults =
    resource: group: version: kind:
    catAttrs "default" (
      filter (
        default:
        (default.resource == null || default.resource == resource)
        && (default.group == null || default.group == group)
        && (default.version == null || default.version == version)
        && (default.kind == null || default.kind == kind)
      ) config.defaults
    );

  types = lib.types // rec {
    str = mkOptionType {
      name = "str";
      description = "string";
      check = isString;
      merge = mergeEqualOption;
    };

    # Either value of type `finalType` or `coercedType`, the latter is
    # converted to `finalType` using `coerceFunc`.
    coercedTo =
      coercedType: coerceFunc: finalType:
      mkOptionType rec {
        inherit (finalType) getSubOptions getSubModules;

        name = "coercedTo";
        description = "${finalType.description} or ${coercedType.description}";
        check = x: finalType.check x || coercedType.check x;
        merge =
          loc: defs:
          let
            coerceVal =
              val:
              if finalType.check val then
                val
              else
                let
                  coerced = coerceFunc val;
                in
                assert finalType.check coerced;
                coerced;

          in
          finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
        substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
        typeMerge = t1: t2: null;
        functor = (defaultFunctor name) // {
          wrapped = finalType;
        };
      };
  };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey =
    attrMergeKey: listMergeKeys: values:
    listToAttrs (
      imap0 (
        i: value:
        nameValuePair (
          if hasAttr attrMergeKey value then
            if isAttrs value.${attrMergeKey} then
              toString value.${attrMergeKey}.content
            else
              (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (
              map (
                key: if isAttrs value.${key} then toString value.${key}.content else (toString value.${key})
              ) listMergeKeys
            ))
        ) (value // { _priority = i; })
      ) values
    );

  submoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = definitions."${ref}".options or { };
        config = definitions."${ref}".config or { };
      }
    );

  globalSubmoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = config.definitions."${ref}".options or { };
        config = config.definitions."${ref}".config or { };
      }
    );

  submoduleWithMergeOf =
    ref: mergeKey:
    types.submodule (
      { name, ... }:
      let
        convertName =
          name: if definitions."${ref}".options.${mergeKey}.type == types.int then toInt name else name;
      in
      {
        options = definitions."${ref}".options // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
            internal = true;
          };
        };
        config = definitions."${ref}".config // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name) then convertName name else null
          );
        };
      }
    );

  submoduleForDefinition =
    ref: resource: kind: group: version:
    let
      apiVersion = if group == "core" then version else "${group}/${version}";
    in
    types.submodule (
      { name, ... }:
      {
        inherit (definitions."${ref}") options;

        imports = getDefaults resource group version kind;
        config = mkMerge [
          definitions."${ref}".config
          {
            kind = mkOptionDefault kind;
            apiVersion = mkOptionDefault apiVersion;

            # metdata.name cannot use option default, due deep config
            metadata.name = mkOptionDefault name;
          }
        ];
      }
    );

  coerceAttrsOfSubmodulesToListByKey =
    ref: attrMergeKey: listMergeKeys:
    (types.coercedTo (types.listOf (submoduleOf ref)) (mergeValuesByKey attrMergeKey listMergeKeys) (
      types.attrsOf (submoduleWithMergeOf ref attrMergeKey)
    ));

  definitions = {
    "gateway.networking.k8s.io.v1.BackendTLSPolicy" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of BackendTLSPolicy.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicySpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of BackendTLSPolicy.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicyStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicySpec" = {

      options = {
        "options" = mkOption {
          description = "Options are a list of key/value pairs to enable extended TLS\nconfiguration for each implementation. For example, configuring the\nminimum TLS version or supported cipher suites.\n\nA set of common keys MAY be defined by the API in the future. To avoid\nany ambiguity, implementation-specific definitions MUST use\ndomain-prefixed names, such as `example.com/my-custom-option`.\nUn-prefixed names are reserved for key names defined by Gateway API.\n\nSupport: Implementation-specific";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "targetRefs" = mkOption {
          description = "TargetRefs identifies an API object to apply the policy to.\nOnly Services have Extended support. Implementations MAY support\nadditional objects, with Implementation Specific support.\nNote that this config applies to the entire referenced resource\nby default, but this default may change in the future to provide\na more granular application of the policy.\n\nTargetRefs must be _distinct_. This means either that:\n\n* They select different targets. If this is the case, then targetRef\n  entries are distinct. In terms of fields, this means that the\n  multi-part key defined by `group`, `kind`, and `name` must\n  be unique across all targetRef entries in the BackendTLSPolicy.\n* They select different sectionNames in the same target.\n\nWhen more than one BackendTLSPolicy selects the same target and\nsectionName, implementations MUST determine precedence using the\nfollowing criteria, continuing on ties:\n\n* The older policy by creation timestamp takes precedence. For\n  example, a policy with a creation timestamp of \"2021-07-15\n  01:02:03\" MUST be given precedence over a policy with a\n  creation timestamp of \"2021-07-15 01:02:04\".\n* The policy appearing first in alphabetical order by {name}.\n  For example, a policy named `bar` is given precedence over a\n  policy named `baz`.\n\nFor any BackendTLSPolicy that does not take precedence, the\nimplementation MUST ensure the `Accepted` Condition is set to\n`status: False`, with Reason `Conflicted`.\n\nImplementations SHOULD NOT support more than one targetRef at this\ntime. Although the API technically allows for this, the current guidance\nfor conflict resolution and status handling is lacking. Until that can be\nclarified in a future release, the safest approach is to support a single\ntargetRef.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.BackendTLSPolicySpecTargetRefs"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "validation" = mkOption {
          description = "Validation contains backend TLS validation configuration.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidation");
        };
      };

      config = {
        "options" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicySpecTargetRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the target resource.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the target resource.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the target resource.";
          type = types.str;
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. When\nunspecified, this targetRef targets the entire resource. In the following\nresources, SectionName is interpreted as the following:\n\n* Gateway: Listener name\n* HTTPRoute: HTTPRouteRule name\n* Service: Port name\n\nIf a SectionName is specified, but does not exist on the targeted object,\nthe Policy must fail to attach, and the policy implementation should record\na `ResolvedRefs` or similar Condition in the Policy's status.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidation" = {

      options = {
        "caCertificateRefs" = mkOption {
          description = "CACertificateRefs contains one or more references to Kubernetes objects that\ncontain a PEM-encoded TLS CA certificate bundle, which is used to\nvalidate a TLS handshake between the Gateway and backend Pod.\n\nIf CACertificateRefs is empty or unspecified, then WellKnownCACertificates must be\nspecified. Only one of CACertificateRefs or WellKnownCACertificates may be specified,\nnot both. If CACertificateRefs is empty or unspecified, the configuration for\nWellKnownCACertificates MUST be honored instead if supported by the implementation.\n\nA CACertificateRef is invalid if:\n\n* It refers to a resource that cannot be resolved (e.g., the referenced resource\n  does not exist) or is misconfigured (e.g., a ConfigMap does not contain a key\n  named `ca.crt`). In this case, the Reason must be set to `InvalidCACertificateRef`\n  and the Message of the Condition must indicate which reference is invalid and why.\n\n* It refers to an unknown or unsupported kind of resource. In this case, the Reason\n  must be set to `InvalidKind` and the Message of the Condition must explain which\n  kind of resource is unknown or unsupported.\n\n* It refers to a resource in another namespace. This may change in future\n  spec updates.\n\nImplementations MAY choose to perform further validation of the certificate\ncontent (e.g., checking expiry or enforcing specific formats). In such cases,\nan implementation-specific Reason and Message must be set for the invalid reference.\n\nIn all cases, the implementation MUST ensure the `ResolvedRefs` Condition on\nthe BackendTLSPolicy is set to `status: False`, with a Reason and Message\nthat indicate the cause of the error. Connections using an invalid\nCACertificateRef MUST fail, and the client MUST receive an HTTP 5xx error\nresponse. If ALL CACertificateRefs are invalid, the implementation MUST also\nensure the `Accepted` Condition on the BackendTLSPolicy is set to\n`status: False`, with a Reason `NoValidCACertificate`.\n\nA single CACertificateRef to a Kubernetes ConfigMap kind has \"Core\" support.\nImplementations MAY choose to support attaching multiple certificates to\na backend, but this behavior is implementation-specific.\n\nSupport: Core - An optional single reference to a Kubernetes ConfigMap,\nwith the CA certificate in a key named `ca.crt`.\n\nSupport: Implementation-specific - More than one reference, other kinds\nof resources, or a single reference that includes multiple certificates.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidationCaCertificateRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "hostname" = mkOption {
          description = "Hostname is used for two purposes in the connection between Gateways and\nbackends:\n\n1. Hostname MUST be used as the SNI to connect to the backend (RFC 6066).\n2. Hostname MUST be used for authentication and MUST match the certificate\n   served by the matching backend, unless SubjectAltNames is specified.\n3. If SubjectAltNames are specified, Hostname can be used for certificate selection\n   but MUST NOT be used for authentication. If you want to use the value\n   of the Hostname field for authentication, you MUST add it to the SubjectAltNames list.\n\nSupport: Core";
          type = types.str;
        };
        "subjectAltNames" = mkOption {
          description = "SubjectAltNames contains one or more Subject Alternative Names.\nWhen specified the certificate served from the backend MUST\nhave at least one Subject Alternate Name matching one of the specified SubjectAltNames.\n\nSupport: Extended";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidationSubjectAltNames"
              )
            )
          );
        };
        "wellKnownCACertificates" = mkOption {
          description = "WellKnownCACertificates specifies whether system CA certificates may be used in\nthe TLS handshake between the gateway and backend pod.\n\nIf WellKnownCACertificates is unspecified or empty (\"\"), then CACertificateRefs\nmust be specified with at least one entry for a valid configuration. Only one of\nCACertificateRefs or WellKnownCACertificates may be specified, not both.\nIf an implementation does not support the WellKnownCACertificates field, or\nthe supplied value is not recognized, the implementation MUST ensure the\n`Accepted` Condition on the BackendTLSPolicy is set to `status: False`, with\na Reason `Invalid`.\n\nSupport: Implementation-specific";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "caCertificateRefs" = mkOverride 1002 null;
        "subjectAltNames" = mkOverride 1002 null;
        "wellKnownCACertificates" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidationCaCertificateRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicySpecValidationSubjectAltNames" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname contains Subject Alternative Name specified in DNS name format.\nRequired when Type is set to Hostname, ignored otherwise.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type determines the format of the Subject Alternative Name. Always required.\n\nSupport: Core";
          type = types.str;
        };
        "uri" = mkOption {
          description = "URI contains Subject Alternative Name specified in a full URI format.\nIt MUST include both a scheme (e.g., \"http\" or \"ftp\") and a scheme-specific-part.\nCommon values include SPIFFE IDs like \"spiffe://mycluster.example.com/ns/myns/sa/svc1sa\".\nRequired when Type is set to URI, ignored otherwise.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "uri" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicyStatus" = {

      options = {
        "ancestors" = mkOption {
          description = "Ancestors is a list of ancestor resources (usually Gateways) that are\nassociated with the policy, and the status of the policy with respect to\neach ancestor. When this policy attaches to a parent, the controller that\nmanages the parent and the ancestors MUST add an entry to this list when\nthe controller first sees the policy and SHOULD update the entry as\nappropriate when the relevant ancestor is modified.\n\nNote that choosing the relevant ancestor is left to the Policy designers;\nan important part of Policy design is designing the right object level at\nwhich to namespace this status.\n\nNote also that implementations MUST ONLY populate ancestor status for\nthe Ancestor resources they are responsible for. Implementations MUST\nuse the ControllerName field to uniquely identify the entries in this list\nthat they are responsible for.\n\nNote that to achieve this, the list of PolicyAncestorStatus structs\nMUST be treated as a map with a composite key, made up of the AncestorRef\nand ControllerName fields combined.\n\nA maximum of 16 ancestors will be represented in this list. An empty list\nmeans the Policy is not relevant for any ancestors.\n\nIf this slice is full, implementations MUST NOT add further entries.\nInstead they MUST consider the policy unimplementable and signal that\non any related resources such as the ancestor that would be referenced\nhere. For example, if this list was full on BackendTLSPolicy, no\nadditional Gateways would be able to reference the Service targeted by\nthe BackendTLSPolicy.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestors"));
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestors" = {

      options = {
        "ancestorRef" = mkOption {
          description = "AncestorRef corresponds with a ParentRef in the spec that this\nPolicyAncestorStatus struct describes the status of.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestorsAncestorRef");
        };
        "conditions" = mkOption {
          description = "Conditions describes the status of the Policy with respect to the given Ancestor.";
          type = (
            types.listOf (submoduleOf "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestorsConditions")
          );
        };
        "controllerName" = mkOption {
          description = "ControllerName is a domain/path string that indicates the name of the\ncontroller that wrote this status. This corresponds with the\ncontrollerName field on GatewayClass.\n\nExample: \"example.net/gateway-controller\".\n\nThe format of this field is DOMAIN \"/\" PATH, where DOMAIN and PATH are\nvalid Kubernetes names\n(https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names).\n\nControllers MUST populate this field when writing status. Controllers should ensure that\nentries to status populated with their ControllerName are cleaned up when they are no\nlonger necessary.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestorsAncestorRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.BackendTLSPolicyStatusAncestorsConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRoute" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of GRPCRoute.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of GRPCRoute.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpec" = {

      options = {
        "hostnames" = mkOption {
          description = "Hostnames defines a set of hostnames to match against the GRPC\nHost header to select a GRPCRoute to process the request. This matches\nthe RFC 1123 definition of a hostname with 2 notable exceptions:\n\n1. IPs are not allowed.\n2. A hostname may be prefixed with a wildcard label (`*.`). The wildcard\n   label MUST appear by itself as the first label.\n\nIf a hostname is specified by both the Listener and GRPCRoute, there\nMUST be at least one intersecting hostname for the GRPCRoute to be\nattached to the Listener. For example:\n\n* A Listener with `test.example.com` as the hostname matches GRPCRoutes\n  that have either not specified any hostnames, or have specified at\n  least one of `test.example.com` or `*.example.com`.\n* A Listener with `*.example.com` as the hostname matches GRPCRoutes\n  that have either not specified any hostnames or have specified at least\n  one hostname that matches the Listener hostname. For example,\n  `test.example.com` and `*.example.com` would both match. On the other\n  hand, `example.com` and `test.example.net` would not match.\n\nHostnames that are prefixed with a wildcard label (`*.`) are interpreted\nas a suffix match. That means that a match for `*.example.com` would match\nboth `test.example.com`, and `foo.test.example.com`, but not `example.com`.\n\nIf both the Listener and GRPCRoute have specified hostnames, any\nGRPCRoute hostnames that do not match the Listener hostname MUST be\nignored. For example, if a Listener specified `*.example.com`, and the\nGRPCRoute specified `test.example.com` and `test.example.net`,\n`test.example.net` MUST NOT be considered for a match.\n\nIf both the Listener and GRPCRoute have specified hostnames, and none\nmatch with the criteria above, then the GRPCRoute MUST NOT be accepted by\nthe implementation. The implementation MUST raise an 'Accepted' Condition\nwith a status of `False` in the corresponding RouteParentStatus.\n\nIf a Route (A) of type HTTPRoute or GRPCRoute is attached to a\nListener and that listener already has another Route (B) of the other\ntype attached and the intersection of the hostnames of A and B is\nnon-empty, then the implementation MUST accept exactly one of these two\nroutes, determined by the following criteria, in order:\n\n* The oldest Route based on creation timestamp.\n* The Route appearing first in alphabetical order by\n  \"{namespace}/{name}\".\n\nThe rejected Route MUST raise an 'Accepted' condition with a status of\n'False' in the corresponding RouteParentStatus.\n\nSupport: Core";
          type = (types.nullOr (types.listOf types.str));
        };
        "parentRefs" = mkOption {
          description = "ParentRefs references the resources (usually Gateways) that a Route wants\nto be attached to. Note that the referenced parent resource needs to\nallow this for the attachment to be complete. For Gateways, that means\nthe Gateway needs to allow attachment from Routes of this kind and\nnamespace. For Services, that means the Service must either be in the same\nnamespace for a \"producer\" route, or the mesh implementation must support\nand allow \"consumer\" routes for the referenced Service. ReferenceGrant is\nnot applicable for governing ParentRefs to Services - it is not possible to\ncreate a \"producer\" route for a Service in a different namespace from the\nRoute.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nThis API may be extended in the future to support additional kinds of parent\nresources.\n\nParentRefs must be _distinct_. This means either that:\n\n* They select different objects.  If this is the case, then parentRef\n  entries are distinct. In terms of fields, this means that the\n  multi-part key defined by `group`, `kind`, `namespace`, and `name` must\n  be unique across all parentRef entries in the Route.\n* They do not select different objects, but for each optional field used,\n  each ParentRef that selects the same object must set the same set of\n  optional fields to different values. If one ParentRef sets a\n  combination of optional fields, all must set the same combination.\n\nSome examples:\n\n* If one ParentRef sets `sectionName`, all ParentRefs referencing the\n  same object must also set `sectionName`.\n* If one ParentRef sets `port`, all ParentRefs referencing the same\n  object must also set `port`.\n* If one ParentRef sets `sectionName` and `port`, all ParentRefs\n  referencing the same object must also set `sectionName` and `port`.\n\nIt is possible to separately reference multiple distinct objects that may\nbe collapsed by an implementation. For example, some implementations may\nchoose to merge compatible Gateway Listeners together. If that is the\ncase, the list of routes attached to those resources should also be\nmerged.\n\nNote that for ParentRefs that cross namespace boundaries, there are specific\nrules. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example,\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable other kinds of cross-namespace reference.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GRPCRouteSpecParentRefs" "name" [ ]
            )
          );
          apply = attrsToList;
        };
        "rules" = mkOption {
          description = "Rules are a list of GRPC matchers, filters and actions.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GRPCRouteSpecRules" "name" [ ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "hostnames" = mkOverride 1002 null;
        "parentRefs" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecParentRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRules" = {

      options = {
        "backendRefs" = mkOption {
          description = "BackendRefs defines the backend(s) where matching requests should be\nsent.\n\nFailure behavior here depends on how many BackendRefs are specified and\nhow many are invalid.\n\nIf *all* entries in BackendRefs are invalid, and there are also no filters\nspecified in this route rule, *all* traffic which matches this rule MUST\nreceive an `UNAVAILABLE` status.\n\nSee the GRPCBackendRef definition for the rules about what makes a single\nGRPCBackendRef invalid.\n\nWhen a GRPCBackendRef is invalid, `UNAVAILABLE` statuses MUST be returned for\nrequests that would have otherwise been routed to an invalid backend. If\nmultiple backends are specified, and some are invalid, the proportion of\nrequests that would otherwise have been routed to an invalid backend\nMUST receive an `UNAVAILABLE` status.\n\nFor example, if two backends are specified with equal weights, and one is\ninvalid, 50 percent of traffic MUST receive an `UNAVAILABLE` status.\nImplementations may choose how that 50 percent is determined.\n\nSupport: Core for Kubernetes Service\n\nSupport: Implementation-specific for any other resource\n\nSupport for weight: Core";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "filters" = mkOption {
          description = "Filters define the filters that are applied to requests that match\nthis rule.\n\nThe effects of ordering of multiple behaviors are currently unspecified.\nThis can change in the future based on feedback during the alpha stage.\n\nConformance-levels at this level are defined based on the type of filter:\n\n- ALL core filters MUST be supported by all implementations that support\n  GRPCRoute.\n- Implementers are encouraged to support extended filters.\n- Implementation-specific custom filters have no API guarantees across\n  implementations.\n\nSpecifying the same filter multiple times is not supported unless explicitly\nindicated in the filter.\n\nIf an implementation cannot support a combination of filters, it must clearly\ndocument that limitation. In cases where incompatible or unsupported\nfilters are specified and cause the `Accepted` condition to be set to status\n`False`, implementations may use the `IncompatibleFilters` reason to specify\nthis configuration error.\n\nSupport: Core";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFilters"))
          );
        };
        "matches" = mkOption {
          description = "Matches define conditions used for matching the rule against incoming\ngRPC requests. Each match is independent, i.e. this rule will be matched\nif **any** one of the matches is satisfied.\n\nFor example, take the following matches configuration:\n\n```\nmatches:\n- method:\n    service: foo.bar\n  headers:\n    values:\n      version: 2\n- method:\n    service: foo.bar.v2\n```\n\nFor a request to match against this rule, it MUST satisfy\nEITHER of the two conditions:\n\n- service of foo.bar AND contains the header `version: 2`\n- service of foo.bar.v2\n\nSee the documentation for GRPCRouteMatch on how to specify multiple\nmatch conditions to be ANDed together.\n\nIf no matches are specified, the implementation MUST match every gRPC request.\n\nProxy or Load Balancer routing configuration generated from GRPCRoutes\nMUST prioritize rules based on the following criteria, continuing on\nties. Merging MUST not be done between GRPCRoutes and HTTPRoutes.\nPrecedence MUST be given to the rule with the largest number of:\n\n* Characters in a matching non-wildcard hostname.\n* Characters in a matching hostname.\n* Characters in a matching service.\n* Characters in a matching method.\n* Header matches.\n\nIf ties still exist across multiple Routes, matching precedence MUST be\ndetermined in order of the following criteria, continuing on ties:\n\n* The oldest Route based on creation timestamp.\n* The Route appearing first in alphabetical order by\n  \"{namespace}/{name}\".\n\nIf ties still exist within the Route that has been given precedence,\nmatching precedence MUST be granted to the first matching rule meeting\nthe above criteria.";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatches"))
          );
        };
        "name" = mkOption {
          description = "Name is the name of the route rule. This name MUST be unique within a Route if it is set.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "backendRefs" = mkOverride 1002 null;
        "filters" = mkOverride 1002 null;
        "matches" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefs" = {

      options = {
        "filters" = mkOption {
          description = "Filters defined at this level MUST be executed if and only if the\nrequest is being forwarded to the backend defined here.\n\nSupport: Implementation-specific (For broader support of filters, use the\nFilters field in GRPCRouteRule.)";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFilters")
            )
          );
        };
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
        "weight" = mkOption {
          description = "Weight specifies the proportion of requests forwarded to the referenced\nbackend. This is computed as weight/(sum of all weights in this\nBackendRefs list). For non-zero values, there may be some epsilon from\nthe exact proportion defined here depending on the precision an\nimplementation supports. Weight is not a percentage and the sum of\nweights does not need to equal 100.\n\nIf only one backend is specified and it has a weight greater than 0, 100%\nof the traffic is forwarded to that backend. If weight is set to 0, no\ntraffic should be forwarded for this entry. If unspecified, weight\ndefaults to 1.\n\nSupport for this field varies based on the context where used.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "filters" = mkOverride 1002 null;
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nSupport: Implementation-specific\n\nThis filter can be used multiple times within the same rule.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersExtensionRef"
            )
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirror"
            )
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations supporting GRPCRoute MUST support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` MUST be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.";
          type = types.str;
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nSupport: Implementation-specific\n\nThis filter can be used multiple times within the same rule.";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersExtensionRef")
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirror")
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations supporting GRPCRoute MUST support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` MUST be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.";
          type = types.str;
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesFiltersResponseHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatches" = {

      options = {
        "headers" = mkOption {
          description = "Headers specifies gRPC request header matchers. Multiple match values are\nANDed together, meaning, a request MUST match all the specified headers\nto select the route.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatchesHeaders"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "method" = mkOption {
          description = "Method specifies a gRPC request service/method matcher. If this field is\nnot specified, all services and methods will match.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatchesMethod"));
        };
      };

      config = {
        "headers" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatchesHeaders" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the gRPC Header to be matched.\n\nIf multiple entries specify equivalent header names, only the first\nentry with an equivalent name MUST be considered for a match. Subsequent\nentries with an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type specifies how to match against the value of the header.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value is the value of the gRPC Header to be matched.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteSpecRulesMatchesMethod" = {

      options = {
        "method" = mkOption {
          description = "Value of the method to match against. If left empty or omitted, will\nmatch all services.\n\nAt least one of Service and Method MUST be a non-empty string.";
          type = (types.nullOr types.str);
        };
        "service" = mkOption {
          description = "Value of the service to match against. If left empty or omitted, will\nmatch any service.\n\nAt least one of Service and Method MUST be a non-empty string.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type specifies how to match against the service and/or method.\nSupport: Core (Exact with service and method specified)\n\nSupport: Implementation-specific (Exact with method specified but no service specified)\n\nSupport: Implementation-specific (RegularExpression)";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "method" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteStatus" = {

      options = {
        "parents" = mkOption {
          description = "Parents is a list of parent resources (usually Gateways) that are\nassociated with the route, and the status of the route with respect to\neach parent. When this route attaches to a parent, the controller that\nmanages the parent must add an entry to this list when the controller\nfirst sees the route and should update the entry as appropriate when the\nroute or gateway is modified.\n\nNote that parent references that cannot be resolved by an implementation\nof this API will not be added to this list. Implementations of this API\ncan only populate Route status for the Gateways/parent resources they are\nresponsible for.\n\nA maximum of 32 Gateways will be represented in this list. An empty list\nmeans the route has not been attached to any Gateway.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteStatusParents"));
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteStatusParents" = {

      options = {
        "conditions" = mkOption {
          description = "Conditions describes the status of the route with respect to the Gateway.\nNote that the route's availability is also subject to the Gateway's own\nstatus conditions and listener status.\n\nIf the Route's ParentRef specifies an existing Gateway that supports\nRoutes of this kind AND that Gateway's controller has sufficient access,\nthen that Gateway's controller MUST set the \"Accepted\" condition on the\nRoute, to indicate whether the route has been accepted or rejected by the\nGateway, and why.\n\nA Route MUST be considered \"Accepted\" if at least one of the Route's\nrules is implemented by the Gateway.\n\nThere are a number of cases where the \"Accepted\" condition may not be set\ndue to lack of controller visibility, that includes when:\n\n* The Route refers to a nonexistent parent.\n* The Route is of a type that the controller does not support.\n* The Route is in a namespace the controller does not have access to.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteStatusParentsConditions"));
        };
        "controllerName" = mkOption {
          description = "ControllerName is a domain/path string that indicates the name of the\ncontroller that wrote this status. This corresponds with the\ncontrollerName field on GatewayClass.\n\nExample: \"example.net/gateway-controller\".\n\nThe format of this field is DOMAIN \"/\" PATH, where DOMAIN and PATH are\nvalid Kubernetes names\n(https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names).\n\nControllers MUST populate this field when writing status. Controllers should ensure that\nentries to status populated with their ControllerName are cleaned up when they are no\nlonger necessary.";
          type = types.str;
        };
        "parentRef" = mkOption {
          description = "ParentRef corresponds with a ParentRef in the spec that this\nRouteParentStatus struct describes the status of.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.GRPCRouteStatusParentsParentRef");
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteStatusParentsConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GRPCRouteStatusParentsParentRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.Gateway" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of Gateway.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of Gateway.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewayStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClass" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of GatewayClass.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.GatewayClassSpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of GatewayClass.\n\nImplementations MUST populate status on all GatewayClass resources which\nspecify their controller name.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewayClassStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClassSpec" = {

      options = {
        "controllerName" = mkOption {
          description = "ControllerName is the name of the controller that is managing Gateways of\nthis class. The value of this field MUST be a domain prefixed path.\n\nExample: \"example.net/gateway-controller\".\n\nThis field is not mutable and cannot be empty.\n\nSupport: Core";
          type = types.str;
        };
        "description" = mkOption {
          description = "Description helps describe a GatewayClass with more details.";
          type = (types.nullOr types.str);
        };
        "parametersRef" = mkOption {
          description = "ParametersRef is a reference to a resource that contains the configuration\nparameters corresponding to the GatewayClass. This is optional if the\ncontroller does not require any additional configuration.\n\nParametersRef can reference a standard Kubernetes resource, i.e. ConfigMap,\nor an implementation-specific custom resource. The resource can be\ncluster-scoped or namespace-scoped.\n\nIf the referent cannot be found, refers to an unsupported kind, or when\nthe data within that resource is malformed, the GatewayClass SHOULD be\nrejected with the \"Accepted\" status condition set to \"False\" and an\n\"InvalidParameters\" reason.\n\nA Gateway for this GatewayClass may provide its own `parametersRef`. When both are specified,\nthe merging behavior is implementation specific.\nIt is generally recommended that GatewayClass provides defaults that can be overridden by a Gateway.\n\nSupport: Implementation-specific";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewayClassSpecParametersRef"));
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "parametersRef" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClassSpecParametersRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent.\nThis field is required when referring to a Namespace-scoped resource and\nMUST be unset when referring to a Cluster-scoped resource.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClassStatus" = {

      options = {
        "conditions" = mkOption {
          description = "Conditions is the current status from the controller for\nthis GatewayClass.\n\nControllers should prefer to publish conditions using values\nof GatewayClassConditionType for the type of each Condition.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewayClassStatusConditions")
            )
          );
        };
        "supportedFeatures" = mkOption {
          description = "SupportedFeatures is the set of features the GatewayClass support.\nIt MUST be sorted in ascending alphabetical order by the Name key.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GatewayClassStatusSupportedFeatures"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "supportedFeatures" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClassStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayClassStatusSupportedFeatures" = {

      options = {
        "name" = mkOption {
          description = "FeatureName is used to describe distinct features that are covered by\nconformance tests.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GatewaySpec" = {

      options = {
        "addresses" = mkOption {
          description = "Addresses requested for this Gateway. This is optional and behavior can\ndepend on the implementation. If a value is set in the spec and the\nrequested address is invalid or unavailable, the implementation MUST\nindicate this in an associated entry in GatewayStatus.Conditions.\n\nThe Addresses field represents a request for the address(es) on the\n\"outside of the Gateway\", that traffic bound for this Gateway will use.\nThis could be the IP address or hostname of an external load balancer or\nother networking infrastructure, or some other address that traffic will\nbe sent to.\n\nIf no Addresses are specified, the implementation MAY schedule the\nGateway in an implementation-specific manner, assigning an appropriate\nset of Addresses.\n\nThe implementation MUST bind all Listeners to every GatewayAddress that\nit assigns to the Gateway and add a corresponding entry in\nGatewayStatus.Addresses.\n\nSupport: Extended";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecAddresses"))
          );
        };
        "gatewayClassName" = mkOption {
          description = "GatewayClassName used for this Gateway. This is the name of a\nGatewayClass resource.";
          type = types.str;
        };
        "infrastructure" = mkOption {
          description = "Infrastructure defines infrastructure level attributes about this Gateway instance.\n\nSupport: Extended";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecInfrastructure"));
        };
        "listeners" = mkOption {
          description = "Listeners associated with this Gateway. Listeners define\nlogical endpoints that are bound on this Gateway's addresses.\nAt least one Listener MUST be specified.\n\n## Distinct Listeners\n\nEach Listener in a set of Listeners (for example, in a single Gateway)\nMUST be _distinct_, in that a traffic flow MUST be able to be assigned to\nexactly one listener. (This section uses \"set of Listeners\" rather than\n\"Listeners in a single Gateway\" because implementations MAY merge configuration\nfrom multiple Gateways onto a single data plane, and these rules _also_\napply in that case).\n\nPractically, this means that each listener in a set MUST have a unique\ncombination of Port, Protocol, and, if supported by the protocol, Hostname.\n\nSome combinations of port, protocol, and TLS settings are considered\nCore support and MUST be supported by implementations based on the objects\nthey support:\n\nHTTPRoute\n\n1. HTTPRoute, Port: 80, Protocol: HTTP\n2. HTTPRoute, Port: 443, Protocol: HTTPS, TLS Mode: Terminate, TLS keypair provided\n\nTLSRoute\n\n1. TLSRoute, Port: 443, Protocol: TLS, TLS Mode: Passthrough\n\n\"Distinct\" Listeners have the following property:\n\n**The implementation can match inbound requests to a single distinct\nListener**.\n\nWhen multiple Listeners share values for fields (for\nexample, two Listeners with the same Port value), the implementation\ncan match requests to only one of the Listeners using other\nListener fields.\n\nWhen multiple listeners have the same value for the Protocol field, then\neach of the Listeners with matching Protocol values MUST have different\nvalues for other fields.\n\nThe set of fields that MUST be different for a Listener differs per protocol.\nThe following rules define the rules for what fields MUST be considered for\nListeners to be distinct with each protocol currently defined in the\nGateway API spec.\n\nThe set of listeners that all share a protocol value MUST have _different_\nvalues for _at least one_ of these fields to be distinct:\n\n* **HTTP, HTTPS, TLS**: Port, Hostname\n* **TCP, UDP**: Port\n\nOne **very** important rule to call out involves what happens when an\nimplementation:\n\n* Supports TCP protocol Listeners, as well as HTTP, HTTPS, or TLS protocol\n  Listeners, and\n* sees HTTP, HTTPS, or TLS protocols with the same `port` as one with TCP\n  Protocol.\n\nIn this case all the Listeners that share a port with the\nTCP Listener are not distinct and so MUST NOT be accepted.\n\nIf an implementation does not support TCP Protocol Listeners, then the\nprevious rule does not apply, and the TCP Listeners SHOULD NOT be\naccepted.\n\nNote that the `tls` field is not used for determining if a listener is distinct, because\nListeners that _only_ differ on TLS config will still conflict in all cases.\n\n### Listeners that are distinct only by Hostname\n\nWhen the Listeners are distinct based only on Hostname, inbound request\nhostnames MUST match from the most specific to least specific Hostname\nvalues to choose the correct Listener and its associated set of Routes.\n\nExact matches MUST be processed before wildcard matches, and wildcard\nmatches MUST be processed before fallback (empty Hostname value)\nmatches. For example, `\"foo.example.com\"` takes precedence over\n`\"*.example.com\"`, and `\"*.example.com\"` takes precedence over `\"\"`.\n\nAdditionally, if there are multiple wildcard entries, more specific\nwildcard entries must be processed before less specific wildcard entries.\nFor example, `\"*.foo.example.com\"` takes precedence over `\"*.example.com\"`.\n\nThe precise definition here is that the higher the number of dots in the\nhostname to the right of the wildcard character, the higher the precedence.\n\nThe wildcard character will match any number of characters _and dots_ to\nthe left, however, so `\"*.example.com\"` will match both\n`\"foo.bar.example.com\"` _and_ `\"bar.example.com\"`.\n\n## Handling indistinct Listeners\n\nIf a set of Listeners contains Listeners that are not distinct, then those\nListeners are _Conflicted_, and the implementation MUST set the \"Conflicted\"\ncondition in the Listener Status to \"True\".\n\nThe words \"indistinct\" and \"conflicted\" are considered equivalent for the\npurpose of this documentation.\n\nImplementations MAY choose to accept a Gateway with some Conflicted\nListeners only if they only accept the partial Listener set that contains\nno Conflicted Listeners.\n\nSpecifically, an implementation MAY accept a partial Listener set subject to\nthe following rules:\n\n* The implementation MUST NOT pick one conflicting Listener as the winner.\n  ALL indistinct Listeners must not be accepted for processing.\n* At least one distinct Listener MUST be present, or else the Gateway effectively\n  contains _no_ Listeners, and must be rejected from processing as a whole.\n\nThe implementation MUST set a \"ListenersNotValid\" condition on the\nGateway Status when the Gateway contains Conflicted Listeners whether or\nnot they accept the Gateway. That Condition SHOULD clearly\nindicate in the Message which Listeners are conflicted, and which are\nAccepted. Additionally, the Listener status for those listeners SHOULD\nindicate which Listeners are conflicted and not Accepted.\n\n## General Listener behavior\n\nNote that, for all distinct Listeners, requests SHOULD match at most one Listener.\nFor example, if Listeners are defined for \"foo.example.com\" and \"*.example.com\", a\nrequest to \"foo.example.com\" SHOULD only be routed using routes attached\nto the \"foo.example.com\" Listener (and not the \"*.example.com\" Listener).\n\nThis concept is known as \"Listener Isolation\", and it is an Extended feature\nof Gateway API. Implementations that do not support Listener Isolation MUST\nclearly document this, and MUST NOT claim support for the\n`GatewayHTTPListenerIsolation` feature.\n\nImplementations that _do_ support Listener Isolation SHOULD claim support\nfor the Extended `GatewayHTTPListenerIsolation` feature and pass the associated\nconformance tests.\n\n## Compatible Listeners\n\nA Gateway's Listeners are considered _compatible_ if:\n\n1. They are distinct.\n2. The implementation can serve them in compliance with the Addresses\n   requirement that all Listeners are available on all assigned\n   addresses.\n\nCompatible combinations in Extended support are expected to vary across\nimplementations. A combination that is compatible for one implementation\nmay not be compatible for another.\n\nFor example, an implementation that cannot serve both TCP and UDP listeners\non the same address, or cannot mix HTTPS and generic TLS listens on the same port\nwould not consider those cases compatible, even though they are distinct.\n\nImplementations MAY merge separate Gateways onto a single set of\nAddresses if all Listeners across all Gateways are compatible.\n\nIn a future release the MinItems=1 requirement MAY be dropped.\n\nSupport: Core";
          type = (
            coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GatewaySpecListeners" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "addresses" = mkOverride 1002 null;
        "infrastructure" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecAddresses" = {

      options = {
        "type" = mkOption {
          description = "Type of the address.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "When a value is unspecified, an implementation SHOULD automatically\nassign an address matching the requested type if possible.\n\nIf an implementation does not support an empty value, they MUST set the\n\"Programmed\" condition in status to False with a reason of \"AddressNotAssigned\".\n\nExamples: `1.2.3.4`, `128::1`, `my-ip-address`.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecInfrastructure" = {

      options = {
        "annotations" = mkOption {
          description = "Annotations that SHOULD be applied to any resources created in response to this Gateway.\n\nFor implementations creating other Kubernetes objects, this should be the `metadata.annotations` field on resources.\nFor other implementations, this refers to any relevant (implementation specific) \"annotations\" concepts.\n\nAn implementation may chose to add additional implementation-specific annotations as they see fit.\n\nSupport: Extended";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "labels" = mkOption {
          description = "Labels that SHOULD be applied to any resources created in response to this Gateway.\n\nFor implementations creating other Kubernetes objects, this should be the `metadata.labels` field on resources.\nFor other implementations, this refers to any relevant (implementation specific) \"labels\" concepts.\n\nAn implementation may chose to add additional implementation-specific labels as they see fit.\n\nIf an implementation maps these labels to Pods, or any other resource that would need to be recreated when labels\nchange, it SHOULD clearly warn about this behavior in documentation.\n\nSupport: Extended";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "parametersRef" = mkOption {
          description = "ParametersRef is a reference to a resource that contains the configuration\nparameters corresponding to the Gateway. This is optional if the\ncontroller does not require any additional configuration.\n\nThis follows the same semantics as GatewayClass's `parametersRef`, but on a per-Gateway basis\n\nThe Gateway's GatewayClass may provide its own `parametersRef`. When both are specified,\nthe merging behavior is implementation specific.\nIt is generally recommended that GatewayClass provides defaults that can be overridden by a Gateway.\n\nIf the referent cannot be found, refers to an unsupported kind, or when\nthe data within that resource is malformed, the Gateway SHOULD be\nrejected with the \"Accepted\" status condition set to \"False\" and an\n\"InvalidParameters\" reason.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecInfrastructureParametersRef")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "parametersRef" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecInfrastructureParametersRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListeners" = {

      options = {
        "allowedRoutes" = mkOption {
          description = "AllowedRoutes defines the types of routes that MAY be attached to a\nListener and the trusted namespaces where those Route resources MAY be\npresent.\n\nAlthough a client request may match multiple route rules, only one rule\nmay ultimately receive the request. Matching precedence MUST be\ndetermined in order of the following criteria:\n\n* The most specific match as defined by the Route type.\n* The oldest Route based on creation timestamp. For example, a Route with\n  a creation timestamp of \"2020-09-08 01:02:03\" is given precedence over\n  a Route with a creation timestamp of \"2020-09-08 01:02:04\".\n* If everything else is equivalent, the Route appearing first in\n  alphabetical order (namespace/name) should be given precedence. For\n  example, foo/bar is given precedence over foo/baz.\n\nAll valid rules within a Route attached to this Listener should be\nimplemented. Invalid Route rules can be ignored (sometimes that will mean\nthe full Route). If a Route rule transitions from valid to invalid,\nsupport for that Route rule should be dropped to ensure consistency. For\nexample, even if a filter specified by a Route rule is invalid, the rest\nof the rules within that Route should still be supported.\n\nSupport: Core";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutes")
          );
        };
        "hostname" = mkOption {
          description = "Hostname specifies the virtual hostname to match for protocol types that\ndefine this concept. When unspecified, all hostnames are matched. This\nfield is ignored for protocols that don't require hostname based\nmatching.\n\nImplementations MUST apply Hostname matching appropriately for each of\nthe following protocols:\n\n* TLS: The Listener Hostname MUST match the SNI.\n* HTTP: The Listener Hostname MUST match the Host header of the request.\n* HTTPS: The Listener Hostname SHOULD match both the SNI and Host header.\n  Note that this does not require the SNI and Host header to be the same.\n  The semantics of this are described in more detail below.\n\nTo ensure security, Section 11.1 of RFC-6066 emphasizes that server\nimplementations that rely on SNI hostname matching MUST also verify\nhostnames within the application protocol.\n\nSection 9.1.2 of RFC-7540 provides a mechanism for servers to reject the\nreuse of a connection by responding with the HTTP 421 Misdirected Request\nstatus code. This indicates that the origin server has rejected the\nrequest because it appears to have been misdirected.\n\nTo detect misdirected requests, Gateways SHOULD match the authority of\nthe requests with all the SNI hostname(s) configured across all the\nGateway Listeners on the same port and protocol:\n\n* If another Listener has an exact match or more specific wildcard entry,\n  the Gateway SHOULD return a 421.\n* If the current Listener (selected by SNI matching during ClientHello)\n  does not match the Host:\n    * If another Listener does match the Host the Gateway SHOULD return a\n      421.\n    * If no other Listener matches the Host, the Gateway MUST return a\n      404.\n\nFor HTTPRoute and TLSRoute resources, there is an interaction with the\n`spec.hostnames` array. When both listener and route specify hostnames,\nthere MUST be an intersection between the values for a Route to be\naccepted. For more information, refer to the Route specific Hostnames\ndocumentation.\n\nHostnames that are prefixed with a wildcard label (`*.`) are interpreted\nas a suffix match. That means that a match for `*.example.com` would match\nboth `test.example.com`, and `foo.test.example.com`, but not `example.com`.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the Listener. This name MUST be unique within a\nGateway.\n\nSupport: Core";
          type = types.str;
        };
        "port" = mkOption {
          description = "Port is the network port. Multiple listeners may use the\nsame port, subject to the Listener compatibility rules.\n\nSupport: Core";
          type = types.int;
        };
        "protocol" = mkOption {
          description = "Protocol specifies the network protocol this listener expects to receive.\n\nSupport: Core";
          type = types.str;
        };
        "tls" = mkOption {
          description = "TLS is the TLS configuration for the Listener. This field is required if\nthe Protocol field is \"HTTPS\" or \"TLS\". It is invalid to set this field\nif the Protocol field is \"HTTP\", \"TCP\", or \"UDP\".\n\nThe association of SNIs to Certificate defined in ListenerTLSConfig is\ndefined based on the Hostname field for this listener.\n\nThe GatewayClass MUST use the longest matching SNI out of all\navailable certificates for any TLS handshake.\n\nSupport: Core";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersTls"));
        };
      };

      config = {
        "allowedRoutes" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutes" = {

      options = {
        "kinds" = mkOption {
          description = "Kinds specifies the groups and kinds of Routes that are allowed to bind\nto this Gateway Listener. When unspecified or empty, the kinds of Routes\nselected are determined using the Listener protocol.\n\nA RouteGroupKind MUST correspond to kinds of Routes that are compatible\nwith the application protocol specified in the Listener's Protocol field.\nIf an implementation does not support or recognize this resource type, it\nMUST set the \"ResolvedRefs\" condition to False for this Listener with the\n\"InvalidRouteKinds\" reason.\n\nSupport: Core";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesKinds")
            )
          );
        };
        "namespaces" = mkOption {
          description = "Namespaces indicates namespaces from which Routes may be attached to this\nListener. This is restricted to the namespace of this Gateway by default.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespaces"
            )
          );
        };
      };

      config = {
        "kinds" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesKinds" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the Route.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the kind of the Route.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespaces" = {

      options = {
        "from" = mkOption {
          description = "From indicates where Routes will be selected for this Gateway. Possible\nvalues are:\n\n* All: Routes in all namespaces may be used by this Gateway.\n* Selector: Routes in namespaces selected by the selector may be used by\n  this Gateway.\n* Same: Only Routes in the same namespace may be used by this Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "Selector must be specified when From is set to \"Selector\". In that case,\nonly Routes in Namespaces matching this Selector will be selected by this\nGateway. This field is ignored for other values of \"From\".\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespacesSelector"
            )
          );
        };
      };

      config = {
        "from" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespacesSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespacesSelectorMatchExpressions"
              )
            )
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersAllowedRoutesNamespacesSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersTls" = {

      options = {
        "certificateRefs" = mkOption {
          description = "CertificateRefs contains a series of references to Kubernetes objects that\ncontains TLS certificates and private keys. These certificates are used to\nestablish a TLS handshake for requests that match the hostname of the\nassociated listener.\n\nA single CertificateRef to a Kubernetes Secret has \"Core\" support.\nImplementations MAY choose to support attaching multiple certificates to\na Listener, but this behavior is implementation-specific.\n\nReferences to a resource in different namespace are invalid UNLESS there\nis a ReferenceGrant in the target namespace that allows the certificate\nto be attached. If a ReferenceGrant does not allow this reference, the\n\"ResolvedRefs\" condition MUST be set to False for this listener with the\n\"RefNotPermitted\" reason.\n\nThis field is required to have at least one element when the mode is set\nto \"Terminate\" (default) and is optional otherwise.\n\nCertificateRefs can reference to standard Kubernetes resources, i.e.\nSecret, or implementation-specific custom resources.\n\nSupport: Core - A single reference to a Kubernetes Secret of type kubernetes.io/tls\n\nSupport: Implementation-specific (More than one reference or other resource types)";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.GatewaySpecListenersTlsCertificateRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "mode" = mkOption {
          description = "Mode defines the TLS behavior for the TLS session initiated by the client.\nThere are two possible modes:\n\n- Terminate: The TLS session between the downstream client and the\n  Gateway is terminated at the Gateway. This mode requires certificates\n  to be specified in some way, such as populating the certificateRefs\n  field.\n- Passthrough: The TLS session is NOT terminated by the Gateway. This\n  implies that the Gateway can't decipher the TLS stream except for\n  the ClientHello message of the TLS protocol. The certificateRefs field\n  is ignored in this mode.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "options" = mkOption {
          description = "Options are a list of key/value pairs to enable extended TLS\nconfiguration for each implementation. For example, configuring the\nminimum TLS version or supported cipher suites.\n\nA set of common keys MAY be defined by the API in the future. To avoid\nany ambiguity, implementation-specific definitions MUST use\ndomain-prefixed names, such as `example.com/my-custom-option`.\nUn-prefixed names are reserved for key names defined by Gateway API.\n\nSupport: Implementation-specific";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "certificateRefs" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewaySpecListenersTlsCertificateRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"Secret\".";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referenced object. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayStatus" = {

      options = {
        "addresses" = mkOption {
          description = "Addresses lists the network addresses that have been bound to the\nGateway.\n\nThis list may differ from the addresses provided in the spec under some\nconditions:\n\n  * no addresses are specified, all addresses are dynamically assigned\n  * a combination of specified and dynamic addresses are assigned\n  * a specified address was unusable (e.g. already in use)";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewayStatusAddresses"))
          );
        };
        "conditions" = mkOption {
          description = "Conditions describe the current conditions of the Gateway.\n\nImplementations should prefer to express Gateway conditions\nusing the `GatewayConditionType` and `GatewayConditionReason`\nconstants so that operators and tools can converge on a common\nvocabulary to describe Gateway state.\n\nKnown condition types are:\n\n* \"Accepted\"\n* \"Programmed\"\n* \"Ready\"";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewayStatusConditions"))
          );
        };
        "listeners" = mkOption {
          description = "Listeners provide status for each unique listener port defined in the Spec.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.GatewayStatusListeners" "name" [
                "name"
              ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "addresses" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "listeners" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayStatusAddresses" = {

      options = {
        "type" = mkOption {
          description = "Type of the address.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value of the address. The validity of the values will depend\non the type and support by the controller.\n\nExamples: `1.2.3.4`, `128::1`, `my-ip-address`.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayStatusListeners" = {

      options = {
        "attachedRoutes" = mkOption {
          description = "AttachedRoutes represents the total number of Routes that have been\nsuccessfully attached to this Listener.\n\nSuccessful attachment of a Route to a Listener is based solely on the\ncombination of the AllowedRoutes field on the corresponding Listener\nand the Route's ParentRefs field. A Route is successfully attached to\na Listener when it is selected by the Listener's AllowedRoutes field\nAND the Route has a valid ParentRef selecting the whole Gateway\nresource or a specific Listener as a parent resource (more detail on\nattachment semantics can be found in the documentation on the various\nRoute kinds ParentRefs fields). Listener or Route status does not impact\nsuccessful attachment, i.e. the AttachedRoutes field count MUST be set\nfor Listeners with condition Accepted: false and MUST count successfully\nattached Routes that may themselves have Accepted: false conditions.\n\nUses for this field include troubleshooting Route attachment and\nmeasuring blast radius/impact of changes to a Listener.";
          type = types.int;
        };
        "conditions" = mkOption {
          description = "Conditions describe the current condition of this listener.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewayStatusListenersConditions"));
        };
        "name" = mkOption {
          description = "Name is the name of the Listener that this status corresponds to.";
          type = types.str;
        };
        "supportedKinds" = mkOption {
          description = "SupportedKinds is the list indicating the Kinds supported by this\nlistener. This MUST represent the kinds an implementation supports for\nthat Listener configuration.\n\nIf kinds are specified in Spec that are not supported, they MUST NOT\nappear in this list and an implementation MUST set the \"ResolvedRefs\"\ncondition to \"False\" with the \"InvalidRouteKinds\" reason. If both valid\nand invalid Route kinds are specified, the implementation MUST\nreference the valid Route kinds that have been specified.";
          type = (
            types.listOf (submoduleOf "gateway.networking.k8s.io.v1.GatewayStatusListenersSupportedKinds")
          );
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.GatewayStatusListenersConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.GatewayStatusListenersSupportedKinds" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the Route.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the kind of the Route.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRoute" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of HTTPRoute.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of HTTPRoute.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpec" = {

      options = {
        "hostnames" = mkOption {
          description = "Hostnames defines a set of hostnames that should match against the HTTP Host\nheader to select a HTTPRoute used to process the request. Implementations\nMUST ignore any port value specified in the HTTP Host header while\nperforming a match and (absent of any applicable header modification\nconfiguration) MUST forward this header unmodified to the backend.\n\nValid values for Hostnames are determined by RFC 1123 definition of a\nhostname with 2 notable exceptions:\n\n1. IPs are not allowed.\n2. A hostname may be prefixed with a wildcard label (`*.`). The wildcard\n   label must appear by itself as the first label.\n\nIf a hostname is specified by both the Listener and HTTPRoute, there\nmust be at least one intersecting hostname for the HTTPRoute to be\nattached to the Listener. For example:\n\n* A Listener with `test.example.com` as the hostname matches HTTPRoutes\n  that have either not specified any hostnames, or have specified at\n  least one of `test.example.com` or `*.example.com`.\n* A Listener with `*.example.com` as the hostname matches HTTPRoutes\n  that have either not specified any hostnames or have specified at least\n  one hostname that matches the Listener hostname. For example,\n  `*.example.com`, `test.example.com`, and `foo.test.example.com` would\n  all match. On the other hand, `example.com` and `test.example.net` would\n  not match.\n\nHostnames that are prefixed with a wildcard label (`*.`) are interpreted\nas a suffix match. That means that a match for `*.example.com` would match\nboth `test.example.com`, and `foo.test.example.com`, but not `example.com`.\n\nIf both the Listener and HTTPRoute have specified hostnames, any\nHTTPRoute hostnames that do not match the Listener hostname MUST be\nignored. For example, if a Listener specified `*.example.com`, and the\nHTTPRoute specified `test.example.com` and `test.example.net`,\n`test.example.net` must not be considered for a match.\n\nIf both the Listener and HTTPRoute have specified hostnames, and none\nmatch with the criteria above, then the HTTPRoute is not accepted. The\nimplementation must raise an 'Accepted' Condition with a status of\n`False` in the corresponding RouteParentStatus.\n\nIn the event that multiple HTTPRoutes specify intersecting hostnames (e.g.\noverlapping wildcard matching and exact matching hostnames), precedence must\nbe given to rules from the HTTPRoute with the largest number of:\n\n* Characters in a matching non-wildcard hostname.\n* Characters in a matching hostname.\n\nIf ties exist across multiple Routes, the matching precedence rules for\nHTTPRouteMatches takes over.\n\nSupport: Core";
          type = (types.nullOr (types.listOf types.str));
        };
        "parentRefs" = mkOption {
          description = "ParentRefs references the resources (usually Gateways) that a Route wants\nto be attached to. Note that the referenced parent resource needs to\nallow this for the attachment to be complete. For Gateways, that means\nthe Gateway needs to allow attachment from Routes of this kind and\nnamespace. For Services, that means the Service must either be in the same\nnamespace for a \"producer\" route, or the mesh implementation must support\nand allow \"consumer\" routes for the referenced Service. ReferenceGrant is\nnot applicable for governing ParentRefs to Services - it is not possible to\ncreate a \"producer\" route for a Service in a different namespace from the\nRoute.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nThis API may be extended in the future to support additional kinds of parent\nresources.\n\nParentRefs must be _distinct_. This means either that:\n\n* They select different objects.  If this is the case, then parentRef\n  entries are distinct. In terms of fields, this means that the\n  multi-part key defined by `group`, `kind`, `namespace`, and `name` must\n  be unique across all parentRef entries in the Route.\n* They do not select different objects, but for each optional field used,\n  each ParentRef that selects the same object must set the same set of\n  optional fields to different values. If one ParentRef sets a\n  combination of optional fields, all must set the same combination.\n\nSome examples:\n\n* If one ParentRef sets `sectionName`, all ParentRefs referencing the\n  same object must also set `sectionName`.\n* If one ParentRef sets `port`, all ParentRefs referencing the same\n  object must also set `port`.\n* If one ParentRef sets `sectionName` and `port`, all ParentRefs\n  referencing the same object must also set `sectionName` and `port`.\n\nIt is possible to separately reference multiple distinct objects that may\nbe collapsed by an implementation. For example, some implementations may\nchoose to merge compatible Gateway Listeners together. If that is the\ncase, the list of routes attached to those resources should also be\nmerged.\n\nNote that for ParentRefs that cross namespace boundaries, there are specific\nrules. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example,\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable other kinds of cross-namespace reference.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.HTTPRouteSpecParentRefs" "name" [ ]
            )
          );
          apply = attrsToList;
        };
        "rules" = mkOption {
          description = "Rules are a list of HTTP matchers, filters and actions.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.HTTPRouteSpecRules" "name" [ ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "hostnames" = mkOverride 1002 null;
        "parentRefs" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecParentRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRules" = {

      options = {
        "backendRefs" = mkOption {
          description = "BackendRefs defines the backend(s) where matching requests should be\nsent.\n\nFailure behavior here depends on how many BackendRefs are specified and\nhow many are invalid.\n\nIf *all* entries in BackendRefs are invalid, and there are also no filters\nspecified in this route rule, *all* traffic which matches this rule MUST\nreceive a 500 status code.\n\nSee the HTTPBackendRef definition for the rules about what makes a single\nHTTPBackendRef invalid.\n\nWhen a HTTPBackendRef is invalid, 500 status codes MUST be returned for\nrequests that would have otherwise been routed to an invalid backend. If\nmultiple backends are specified, and some are invalid, the proportion of\nrequests that would otherwise have been routed to an invalid backend\nMUST receive a 500 status code.\n\nFor example, if two backends are specified with equal weights, and one is\ninvalid, 50 percent of traffic must receive a 500. Implementations may\nchoose how that 50 percent is determined.\n\nWhen a HTTPBackendRef refers to a Service that has no ready endpoints,\nimplementations SHOULD return a 503 for requests to that backend instead.\nIf an implementation chooses to do this, all of the above rules for 500 responses\nMUST also apply for responses that return a 503.\n\nSupport: Core for Kubernetes Service\n\nSupport: Extended for Kubernetes ServiceImport\n\nSupport: Implementation-specific for any other resource\n\nSupport for weight: Core";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "filters" = mkOption {
          description = "Filters define the filters that are applied to requests that match\nthis rule.\n\nWherever possible, implementations SHOULD implement filters in the order\nthey are specified.\n\nImplementations MAY choose to implement this ordering strictly, rejecting\nany combination or order of filters that cannot be supported. If implementations\nchoose a strict interpretation of filter ordering, they MUST clearly document\nthat behavior.\n\nTo reject an invalid combination or order of filters, implementations SHOULD\nconsider the Route Rules with this configuration invalid. If all Route Rules\nin a Route are invalid, the entire Route would be considered invalid. If only\na portion of Route Rules are invalid, implementations MUST set the\n\"PartiallyInvalid\" condition for the Route.\n\nConformance-levels at this level are defined based on the type of filter:\n\n- ALL core filters MUST be supported by all implementations.\n- Implementers are encouraged to support extended filters.\n- Implementation-specific custom filters have no API guarantees across\n  implementations.\n\nSpecifying the same filter multiple times is not supported unless explicitly\nindicated in the filter.\n\nAll filters are expected to be compatible with each other except for the\nURLRewrite and RequestRedirect filters, which may not be combined. If an\nimplementation cannot support other combinations of filters, they must clearly\ndocument that limitation. In cases where incompatible or unsupported\nfilters are specified and cause the `Accepted` condition to be set to status\n`False`, implementations may use the `IncompatibleFilters` reason to specify\nthis configuration error.\n\nSupport: Core";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFilters"))
          );
        };
        "matches" = mkOption {
          description = "Matches define conditions used for matching the rule against incoming\nHTTP requests. Each match is independent, i.e. this rule will be matched\nif **any** one of the matches is satisfied.\n\nFor example, take the following matches configuration:\n\n```\nmatches:\n- path:\n    value: \"/foo\"\n  headers:\n  - name: \"version\"\n    value: \"v2\"\n- path:\n    value: \"/v2/foo\"\n```\n\nFor a request to match against this rule, a request must satisfy\nEITHER of the two conditions:\n\n- path prefixed with `/foo` AND contains the header `version: v2`\n- path prefix of `/v2/foo`\n\nSee the documentation for HTTPRouteMatch on how to specify multiple\nmatch conditions that should be ANDed together.\n\nIf no matches are specified, the default is a prefix\npath match on \"/\", which has the effect of matching every\nHTTP request.\n\nProxy or Load Balancer routing configuration generated from HTTPRoutes\nMUST prioritize matches based on the following criteria, continuing on\nties. Across all rules specified on applicable Routes, precedence must be\ngiven to the match having:\n\n* \"Exact\" path match.\n* \"Prefix\" path match with largest number of characters.\n* Method match.\n* Largest number of header matches.\n* Largest number of query param matches.\n\nNote: The precedence of RegularExpression path matches are implementation-specific.\n\nIf ties still exist across multiple Routes, matching precedence MUST be\ndetermined in order of the following criteria, continuing on ties:\n\n* The oldest Route based on creation timestamp.\n* The Route appearing first in alphabetical order by\n  \"{namespace}/{name}\".\n\nIf ties still exist within an HTTPRoute, matching precedence MUST be granted\nto the FIRST matching rule (in list order) with a match meeting the above\ncriteria.\n\nWhen no rules matching a request have been successfully attached to the\nparent a request is coming from, a HTTP 404 status code MUST be returned.";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatches"))
          );
        };
        "name" = mkOption {
          description = "Name is the name of the route rule. This name MUST be unique within a Route if it is set.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "timeouts" = mkOption {
          description = "Timeouts defines the timeouts that can be configured for an HTTP request.\n\nSupport: Extended";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesTimeouts"));
        };
      };

      config = {
        "backendRefs" = mkOverride 1002 null;
        "filters" = mkOverride 1002 null;
        "matches" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "timeouts" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefs" = {

      options = {
        "filters" = mkOption {
          description = "Filters defined at this level should be executed if and only if the\nrequest is being forwarded to the backend defined here.\n\nSupport: Implementation-specific (For broader support of filters, use the\nFilters field in HTTPRouteRule.)";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFilters")
            )
          );
        };
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
        "weight" = mkOption {
          description = "Weight specifies the proportion of requests forwarded to the referenced\nbackend. This is computed as weight/(sum of all weights in this\nBackendRefs list). For non-zero values, there may be some epsilon from\nthe exact proportion defined here depending on the precision an\nimplementation supports. Weight is not a percentage and the sum of\nweights does not need to equal 100.\n\nIf only one backend is specified and it has a weight greater than 0, 100%\nof the traffic is forwarded to that backend. If weight is set to 0, no\ntraffic should be forwarded for this entry. If unspecified, weight\ndefaults to 1.\n\nSupport for this field varies based on the context where used.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "filters" = mkOverride 1002 null;
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nThis filter can be used multiple times within the same rule.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersExtensionRef"
            )
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirror"
            )
          );
        };
        "requestRedirect" = mkOption {
          description = "RequestRedirect defines a schema for a filter that responds to the\nrequest with an HTTP redirection.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirect"
            )
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations must support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by\n  specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` should be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
        "urlRewrite" = mkOption {
          description = "URLRewrite defines a schema for a filter that modifies a request during forwarding.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewrite"
            )
          );
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "requestRedirect" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
        "urlRewrite" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirect" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the hostname to be used in the value of the `Location`\nheader in the response.\nWhen empty, the hostname in the `Host` header of the request is used.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines parameters used to modify the path of the incoming request.\nThe modified path is then used to construct the `Location` header. When\nempty, the request path is used as-is.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirectPath"
            )
          );
        };
        "port" = mkOption {
          description = "Port is the port to be used in the value of the `Location`\nheader in the response.\n\nIf no port is specified, the redirect port MUST be derived using the\nfollowing rules:\n\n* If redirect scheme is not-empty, the redirect port MUST be the well-known\n  port associated with the redirect scheme. Specifically \"http\" to port 80\n  and \"https\" to port 443. If the redirect scheme does not have a\n  well-known port, the listener port of the Gateway SHOULD be used.\n* If redirect scheme is empty, the redirect port MUST be the Gateway\n  Listener port.\n\nImplementations SHOULD NOT add the port number in the 'Location'\nheader in the following cases:\n\n* A Location header that will use HTTP (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 80.\n* A Location header that will use HTTPS (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 443.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "scheme" = mkOption {
          description = "Scheme is the scheme to be used in the value of the `Location` header in\nthe response. When empty, the scheme of the request is used.\n\nScheme redirects can affect the port of the redirect, for more information,\nrefer to the documentation for the port field of this filter.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "statusCode" = mkOption {
          description = "StatusCode is the HTTP status code to be used in response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Core";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "statusCode" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirectPath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewrite" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the value to be used to replace the Host header value during\nforwarding.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines a path rewrite.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewritePath"
            )
          );
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewritePath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nThis filter can be used multiple times within the same rule.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersExtensionRef")
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirror")
          );
        };
        "requestRedirect" = mkOption {
          description = "RequestRedirect defines a schema for a filter that responds to the\nrequest with an HTTP redirection.\n\nSupport: Core";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestRedirect")
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations must support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by\n  specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` should be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
        "urlRewrite" = mkOption {
          description = "URLRewrite defines a schema for a filter that modifies a request during forwarding.\n\nSupport: Extended";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersUrlRewrite")
          );
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "requestRedirect" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
        "urlRewrite" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestRedirect" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the hostname to be used in the value of the `Location`\nheader in the response.\nWhen empty, the hostname in the `Host` header of the request is used.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines parameters used to modify the path of the incoming request.\nThe modified path is then used to construct the `Location` header. When\nempty, the request path is used as-is.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestRedirectPath"
            )
          );
        };
        "port" = mkOption {
          description = "Port is the port to be used in the value of the `Location`\nheader in the response.\n\nIf no port is specified, the redirect port MUST be derived using the\nfollowing rules:\n\n* If redirect scheme is not-empty, the redirect port MUST be the well-known\n  port associated with the redirect scheme. Specifically \"http\" to port 80\n  and \"https\" to port 443. If the redirect scheme does not have a\n  well-known port, the listener port of the Gateway SHOULD be used.\n* If redirect scheme is empty, the redirect port MUST be the Gateway\n  Listener port.\n\nImplementations SHOULD NOT add the port number in the 'Location'\nheader in the following cases:\n\n* A Location header that will use HTTP (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 80.\n* A Location header that will use HTTPS (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 443.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "scheme" = mkOption {
          description = "Scheme is the scheme to be used in the value of the `Location` header in\nthe response. When empty, the scheme of the request is used.\n\nScheme redirects can affect the port of the redirect, for more information,\nrefer to the documentation for the port field of this filter.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "statusCode" = mkOption {
          description = "StatusCode is the HTTP status code to be used in response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Core";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "statusCode" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersRequestRedirectPath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersResponseHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersUrlRewrite" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the value to be used to replace the Host header value during\nforwarding.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines a path rewrite.\n\nSupport: Extended";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersUrlRewritePath")
          );
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesFiltersUrlRewritePath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatches" = {

      options = {
        "headers" = mkOption {
          description = "Headers specifies HTTP request header matchers. Multiple match values are\nANDed together, meaning, a request must match all the specified headers\nto select the route.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesHeaders"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "method" = mkOption {
          description = "Method specifies HTTP method matcher.\nWhen specified, this route will be matched only if the request has the\nspecified method.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path specifies a HTTP request path matcher. If this field is not\nspecified, a default prefix match on the \"/\" path is provided.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesPath"));
        };
        "queryParams" = mkOption {
          description = "QueryParams specifies HTTP query parameter matchers. Multiple match\nvalues are ANDed together, meaning, a request must match all the\nspecified query parameters to select the route.\n\nSupport: Extended";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesQueryParams"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "headers" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "queryParams" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesHeaders" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, only the first\nentry with an equivalent name MUST be considered for a match. Subsequent\nentries with an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.\n\nWhen a header is repeated in an HTTP request, it is\nimplementation-specific behavior as to how this is represented.\nGenerally, proxies should follow the guidance from the RFC:\nhttps://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.2 regarding\nprocessing a repeated header, with special handling for \"Set-Cookie\".";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type specifies how to match against the value of the header.\n\nSupport: Core (Exact)\n\nSupport: Implementation-specific (RegularExpression)\n\nSince RegularExpression HeaderMatchType has implementation-specific\nconformance, implementations can support POSIX, PCRE or any other dialects\nof regular expressions. Please read the implementation's documentation to\ndetermine the supported dialect.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesPath" = {

      options = {
        "type" = mkOption {
          description = "Type specifies how to match against the path Value.\n\nSupport: Core (Exact, PathPrefix)\n\nSupport: Implementation-specific (RegularExpression)";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value of the HTTP path to match against.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesMatchesQueryParams" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP query param to be matched. This must be an\nexact string match. (See\nhttps://tools.ietf.org/html/rfc7230#section-2.7.3).\n\nIf multiple entries specify equivalent query param names, only the first\nentry with an equivalent name MUST be considered for a match. Subsequent\nentries with an equivalent query param name MUST be ignored.\n\nIf a query param is repeated in an HTTP request, the behavior is\npurposely left undefined, since different data planes have different\ncapabilities. However, it is *recommended* that implementations should\nmatch against the first value of the param if the data plane supports it,\nas this behavior is expected in other load balancing contexts outside of\nthe Gateway API.\n\nUsers SHOULD NOT route traffic based on repeated query params to guard\nthemselves against potential differences in the implementations.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type specifies how to match against the value of the query parameter.\n\nSupport: Extended (Exact)\n\nSupport: Implementation-specific (RegularExpression)\n\nSince RegularExpression QueryParamMatchType has Implementation-specific\nconformance, implementations can support POSIX, PCRE or any other\ndialects of regular expressions. Please read the implementation's\ndocumentation to determine the supported dialect.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value is the value of HTTP query param to be matched.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteSpecRulesTimeouts" = {

      options = {
        "backendRequest" = mkOption {
          description = "BackendRequest specifies a timeout for an individual request from the gateway\nto a backend. This covers the time from when the request first starts being\nsent from the gateway to when the full response has been received from the backend.\n\nSetting a timeout to the zero duration (e.g. \"0s\") SHOULD disable the timeout\ncompletely. Implementations that cannot completely disable the timeout MUST\ninstead interpret the zero duration as the longest possible value to which\nthe timeout can be set.\n\nAn entire client HTTP transaction with a gateway, covered by the Request timeout,\nmay result in more than one call from the gateway to the destination backend,\nfor example, if automatic retries are supported.\n\nThe value of BackendRequest must be a Gateway API Duration string as defined by\nGEP-2257.  When this field is unspecified, its behavior is implementation-specific;\nwhen specified, the value of BackendRequest must be no more than the value of the\nRequest timeout (since the Request timeout encompasses the BackendRequest timeout).\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "request" = mkOption {
          description = "Request specifies the maximum duration for a gateway to respond to an HTTP request.\nIf the gateway has not been able to respond before this deadline is met, the gateway\nMUST return a timeout error.\n\nFor example, setting the `rules.timeouts.request` field to the value `10s` in an\n`HTTPRoute` will cause a timeout if a client request is taking longer than 10 seconds\nto complete.\n\nSetting a timeout to the zero duration (e.g. \"0s\") SHOULD disable the timeout\ncompletely. Implementations that cannot completely disable the timeout MUST\ninstead interpret the zero duration as the longest possible value to which\nthe timeout can be set.\n\nThis timeout is intended to cover as close to the whole request-response transaction\nas possible although an implementation MAY choose to start the timeout after the entire\nrequest stream has been received instead of immediately after the transaction is\ninitiated by the client.\n\nThe value of Request is a Gateway API Duration string as defined by GEP-2257. When this\nfield is unspecified, request timeout behavior is implementation-specific.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "backendRequest" = mkOverride 1002 null;
        "request" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteStatus" = {

      options = {
        "parents" = mkOption {
          description = "Parents is a list of parent resources (usually Gateways) that are\nassociated with the route, and the status of the route with respect to\neach parent. When this route attaches to a parent, the controller that\nmanages the parent must add an entry to this list when the controller\nfirst sees the route and should update the entry as appropriate when the\nroute or gateway is modified.\n\nNote that parent references that cannot be resolved by an implementation\nof this API will not be added to this list. Implementations of this API\ncan only populate Route status for the Gateways/parent resources they are\nresponsible for.\n\nA maximum of 32 Gateways will be represented in this list. An empty list\nmeans the route has not been attached to any Gateway.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteStatusParents"));
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteStatusParents" = {

      options = {
        "conditions" = mkOption {
          description = "Conditions describes the status of the route with respect to the Gateway.\nNote that the route's availability is also subject to the Gateway's own\nstatus conditions and listener status.\n\nIf the Route's ParentRef specifies an existing Gateway that supports\nRoutes of this kind AND that Gateway's controller has sufficient access,\nthen that Gateway's controller MUST set the \"Accepted\" condition on the\nRoute, to indicate whether the route has been accepted or rejected by the\nGateway, and why.\n\nA Route MUST be considered \"Accepted\" if at least one of the Route's\nrules is implemented by the Gateway.\n\nThere are a number of cases where the \"Accepted\" condition may not be set\ndue to lack of controller visibility, that includes when:\n\n* The Route refers to a nonexistent parent.\n* The Route is of a type that the controller does not support.\n* The Route is in a namespace the controller does not have access to.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteStatusParentsConditions"));
        };
        "controllerName" = mkOption {
          description = "ControllerName is a domain/path string that indicates the name of the\ncontroller that wrote this status. This corresponds with the\ncontrollerName field on GatewayClass.\n\nExample: \"example.net/gateway-controller\".\n\nThe format of this field is DOMAIN \"/\" PATH, where DOMAIN and PATH are\nvalid Kubernetes names\n(https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names).\n\nControllers MUST populate this field when writing status. Controllers should ensure that\nentries to status populated with their ControllerName are cleaned up when they are no\nlonger necessary.";
          type = types.str;
        };
        "parentRef" = mkOption {
          description = "ParentRef corresponds with a ParentRef in the spec that this\nRouteParentStatus struct describes the status of.";
          type = (submoduleOf "gateway.networking.k8s.io.v1.HTTPRouteStatusParentsParentRef");
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteStatusParentsConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1.HTTPRouteStatusParentsParentRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.Gateway" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of Gateway.";
          type = (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of Gateway.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClass" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of GatewayClass.";
          type = (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayClassSpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of GatewayClass.\n\nImplementations MUST populate status on all GatewayClass resources which\nspecify their controller name.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayClassStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClassSpec" = {

      options = {
        "controllerName" = mkOption {
          description = "ControllerName is the name of the controller that is managing Gateways of\nthis class. The value of this field MUST be a domain prefixed path.\n\nExample: \"example.net/gateway-controller\".\n\nThis field is not mutable and cannot be empty.\n\nSupport: Core";
          type = types.str;
        };
        "description" = mkOption {
          description = "Description helps describe a GatewayClass with more details.";
          type = (types.nullOr types.str);
        };
        "parametersRef" = mkOption {
          description = "ParametersRef is a reference to a resource that contains the configuration\nparameters corresponding to the GatewayClass. This is optional if the\ncontroller does not require any additional configuration.\n\nParametersRef can reference a standard Kubernetes resource, i.e. ConfigMap,\nor an implementation-specific custom resource. The resource can be\ncluster-scoped or namespace-scoped.\n\nIf the referent cannot be found, refers to an unsupported kind, or when\nthe data within that resource is malformed, the GatewayClass SHOULD be\nrejected with the \"Accepted\" status condition set to \"False\" and an\n\"InvalidParameters\" reason.\n\nA Gateway for this GatewayClass may provide its own `parametersRef`. When both are specified,\nthe merging behavior is implementation specific.\nIt is generally recommended that GatewayClass provides defaults that can be overridden by a Gateway.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayClassSpecParametersRef")
          );
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "parametersRef" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClassSpecParametersRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent.\nThis field is required when referring to a Namespace-scoped resource and\nMUST be unset when referring to a Cluster-scoped resource.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClassStatus" = {

      options = {
        "conditions" = mkOption {
          description = "Conditions is the current status from the controller for\nthis GatewayClass.\n\nControllers should prefer to publish conditions using values\nof GatewayClassConditionType for the type of each Condition.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayClassStatusConditions")
            )
          );
        };
        "supportedFeatures" = mkOption {
          description = "SupportedFeatures is the set of features the GatewayClass support.\nIt MUST be sorted in ascending alphabetical order by the Name key.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.GatewayClassStatusSupportedFeatures"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "supportedFeatures" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClassStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayClassStatusSupportedFeatures" = {

      options = {
        "name" = mkOption {
          description = "FeatureName is used to describe distinct features that are covered by\nconformance tests.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpec" = {

      options = {
        "addresses" = mkOption {
          description = "Addresses requested for this Gateway. This is optional and behavior can\ndepend on the implementation. If a value is set in the spec and the\nrequested address is invalid or unavailable, the implementation MUST\nindicate this in an associated entry in GatewayStatus.Conditions.\n\nThe Addresses field represents a request for the address(es) on the\n\"outside of the Gateway\", that traffic bound for this Gateway will use.\nThis could be the IP address or hostname of an external load balancer or\nother networking infrastructure, or some other address that traffic will\nbe sent to.\n\nIf no Addresses are specified, the implementation MAY schedule the\nGateway in an implementation-specific manner, assigning an appropriate\nset of Addresses.\n\nThe implementation MUST bind all Listeners to every GatewayAddress that\nit assigns to the Gateway and add a corresponding entry in\nGatewayStatus.Addresses.\n\nSupport: Extended";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecAddresses"))
          );
        };
        "gatewayClassName" = mkOption {
          description = "GatewayClassName used for this Gateway. This is the name of a\nGatewayClass resource.";
          type = types.str;
        };
        "infrastructure" = mkOption {
          description = "Infrastructure defines infrastructure level attributes about this Gateway instance.\n\nSupport: Extended";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecInfrastructure"));
        };
        "listeners" = mkOption {
          description = "Listeners associated with this Gateway. Listeners define\nlogical endpoints that are bound on this Gateway's addresses.\nAt least one Listener MUST be specified.\n\n## Distinct Listeners\n\nEach Listener in a set of Listeners (for example, in a single Gateway)\nMUST be _distinct_, in that a traffic flow MUST be able to be assigned to\nexactly one listener. (This section uses \"set of Listeners\" rather than\n\"Listeners in a single Gateway\" because implementations MAY merge configuration\nfrom multiple Gateways onto a single data plane, and these rules _also_\napply in that case).\n\nPractically, this means that each listener in a set MUST have a unique\ncombination of Port, Protocol, and, if supported by the protocol, Hostname.\n\nSome combinations of port, protocol, and TLS settings are considered\nCore support and MUST be supported by implementations based on the objects\nthey support:\n\nHTTPRoute\n\n1. HTTPRoute, Port: 80, Protocol: HTTP\n2. HTTPRoute, Port: 443, Protocol: HTTPS, TLS Mode: Terminate, TLS keypair provided\n\nTLSRoute\n\n1. TLSRoute, Port: 443, Protocol: TLS, TLS Mode: Passthrough\n\n\"Distinct\" Listeners have the following property:\n\n**The implementation can match inbound requests to a single distinct\nListener**.\n\nWhen multiple Listeners share values for fields (for\nexample, two Listeners with the same Port value), the implementation\ncan match requests to only one of the Listeners using other\nListener fields.\n\nWhen multiple listeners have the same value for the Protocol field, then\neach of the Listeners with matching Protocol values MUST have different\nvalues for other fields.\n\nThe set of fields that MUST be different for a Listener differs per protocol.\nThe following rules define the rules for what fields MUST be considered for\nListeners to be distinct with each protocol currently defined in the\nGateway API spec.\n\nThe set of listeners that all share a protocol value MUST have _different_\nvalues for _at least one_ of these fields to be distinct:\n\n* **HTTP, HTTPS, TLS**: Port, Hostname\n* **TCP, UDP**: Port\n\nOne **very** important rule to call out involves what happens when an\nimplementation:\n\n* Supports TCP protocol Listeners, as well as HTTP, HTTPS, or TLS protocol\n  Listeners, and\n* sees HTTP, HTTPS, or TLS protocols with the same `port` as one with TCP\n  Protocol.\n\nIn this case all the Listeners that share a port with the\nTCP Listener are not distinct and so MUST NOT be accepted.\n\nIf an implementation does not support TCP Protocol Listeners, then the\nprevious rule does not apply, and the TCP Listeners SHOULD NOT be\naccepted.\n\nNote that the `tls` field is not used for determining if a listener is distinct, because\nListeners that _only_ differ on TLS config will still conflict in all cases.\n\n### Listeners that are distinct only by Hostname\n\nWhen the Listeners are distinct based only on Hostname, inbound request\nhostnames MUST match from the most specific to least specific Hostname\nvalues to choose the correct Listener and its associated set of Routes.\n\nExact matches MUST be processed before wildcard matches, and wildcard\nmatches MUST be processed before fallback (empty Hostname value)\nmatches. For example, `\"foo.example.com\"` takes precedence over\n`\"*.example.com\"`, and `\"*.example.com\"` takes precedence over `\"\"`.\n\nAdditionally, if there are multiple wildcard entries, more specific\nwildcard entries must be processed before less specific wildcard entries.\nFor example, `\"*.foo.example.com\"` takes precedence over `\"*.example.com\"`.\n\nThe precise definition here is that the higher the number of dots in the\nhostname to the right of the wildcard character, the higher the precedence.\n\nThe wildcard character will match any number of characters _and dots_ to\nthe left, however, so `\"*.example.com\"` will match both\n`\"foo.bar.example.com\"` _and_ `\"bar.example.com\"`.\n\n## Handling indistinct Listeners\n\nIf a set of Listeners contains Listeners that are not distinct, then those\nListeners are _Conflicted_, and the implementation MUST set the \"Conflicted\"\ncondition in the Listener Status to \"True\".\n\nThe words \"indistinct\" and \"conflicted\" are considered equivalent for the\npurpose of this documentation.\n\nImplementations MAY choose to accept a Gateway with some Conflicted\nListeners only if they only accept the partial Listener set that contains\nno Conflicted Listeners.\n\nSpecifically, an implementation MAY accept a partial Listener set subject to\nthe following rules:\n\n* The implementation MUST NOT pick one conflicting Listener as the winner.\n  ALL indistinct Listeners must not be accepted for processing.\n* At least one distinct Listener MUST be present, or else the Gateway effectively\n  contains _no_ Listeners, and must be rejected from processing as a whole.\n\nThe implementation MUST set a \"ListenersNotValid\" condition on the\nGateway Status when the Gateway contains Conflicted Listeners whether or\nnot they accept the Gateway. That Condition SHOULD clearly\nindicate in the Message which Listeners are conflicted, and which are\nAccepted. Additionally, the Listener status for those listeners SHOULD\nindicate which Listeners are conflicted and not Accepted.\n\n## General Listener behavior\n\nNote that, for all distinct Listeners, requests SHOULD match at most one Listener.\nFor example, if Listeners are defined for \"foo.example.com\" and \"*.example.com\", a\nrequest to \"foo.example.com\" SHOULD only be routed using routes attached\nto the \"foo.example.com\" Listener (and not the \"*.example.com\" Listener).\n\nThis concept is known as \"Listener Isolation\", and it is an Extended feature\nof Gateway API. Implementations that do not support Listener Isolation MUST\nclearly document this, and MUST NOT claim support for the\n`GatewayHTTPListenerIsolation` feature.\n\nImplementations that _do_ support Listener Isolation SHOULD claim support\nfor the Extended `GatewayHTTPListenerIsolation` feature and pass the associated\nconformance tests.\n\n## Compatible Listeners\n\nA Gateway's Listeners are considered _compatible_ if:\n\n1. They are distinct.\n2. The implementation can serve them in compliance with the Addresses\n   requirement that all Listeners are available on all assigned\n   addresses.\n\nCompatible combinations in Extended support are expected to vary across\nimplementations. A combination that is compatible for one implementation\nmay not be compatible for another.\n\nFor example, an implementation that cannot serve both TCP and UDP listeners\non the same address, or cannot mix HTTPS and generic TLS listens on the same port\nwould not consider those cases compatible, even though they are distinct.\n\nImplementations MAY merge separate Gateways onto a single set of\nAddresses if all Listeners across all Gateways are compatible.\n\nIn a future release the MinItems=1 requirement MAY be dropped.\n\nSupport: Core";
          type = (
            coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.GatewaySpecListeners" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "addresses" = mkOverride 1002 null;
        "infrastructure" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecAddresses" = {

      options = {
        "type" = mkOption {
          description = "Type of the address.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "When a value is unspecified, an implementation SHOULD automatically\nassign an address matching the requested type if possible.\n\nIf an implementation does not support an empty value, they MUST set the\n\"Programmed\" condition in status to False with a reason of \"AddressNotAssigned\".\n\nExamples: `1.2.3.4`, `128::1`, `my-ip-address`.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecInfrastructure" = {

      options = {
        "annotations" = mkOption {
          description = "Annotations that SHOULD be applied to any resources created in response to this Gateway.\n\nFor implementations creating other Kubernetes objects, this should be the `metadata.annotations` field on resources.\nFor other implementations, this refers to any relevant (implementation specific) \"annotations\" concepts.\n\nAn implementation may chose to add additional implementation-specific annotations as they see fit.\n\nSupport: Extended";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "labels" = mkOption {
          description = "Labels that SHOULD be applied to any resources created in response to this Gateway.\n\nFor implementations creating other Kubernetes objects, this should be the `metadata.labels` field on resources.\nFor other implementations, this refers to any relevant (implementation specific) \"labels\" concepts.\n\nAn implementation may chose to add additional implementation-specific labels as they see fit.\n\nIf an implementation maps these labels to Pods, or any other resource that would need to be recreated when labels\nchange, it SHOULD clearly warn about this behavior in documentation.\n\nSupport: Extended";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "parametersRef" = mkOption {
          description = "ParametersRef is a reference to a resource that contains the configuration\nparameters corresponding to the Gateway. This is optional if the\ncontroller does not require any additional configuration.\n\nThis follows the same semantics as GatewayClass's `parametersRef`, but on a per-Gateway basis\n\nThe Gateway's GatewayClass may provide its own `parametersRef`. When both are specified,\nthe merging behavior is implementation specific.\nIt is generally recommended that GatewayClass provides defaults that can be overridden by a Gateway.\n\nIf the referent cannot be found, refers to an unsupported kind, or when\nthe data within that resource is malformed, the Gateway SHOULD be\nrejected with the \"Accepted\" status condition set to \"False\" and an\n\"InvalidParameters\" reason.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecInfrastructureParametersRef"
            )
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "parametersRef" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecInfrastructureParametersRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListeners" = {

      options = {
        "allowedRoutes" = mkOption {
          description = "AllowedRoutes defines the types of routes that MAY be attached to a\nListener and the trusted namespaces where those Route resources MAY be\npresent.\n\nAlthough a client request may match multiple route rules, only one rule\nmay ultimately receive the request. Matching precedence MUST be\ndetermined in order of the following criteria:\n\n* The most specific match as defined by the Route type.\n* The oldest Route based on creation timestamp. For example, a Route with\n  a creation timestamp of \"2020-09-08 01:02:03\" is given precedence over\n  a Route with a creation timestamp of \"2020-09-08 01:02:04\".\n* If everything else is equivalent, the Route appearing first in\n  alphabetical order (namespace/name) should be given precedence. For\n  example, foo/bar is given precedence over foo/baz.\n\nAll valid rules within a Route attached to this Listener should be\nimplemented. Invalid Route rules can be ignored (sometimes that will mean\nthe full Route). If a Route rule transitions from valid to invalid,\nsupport for that Route rule should be dropped to ensure consistency. For\nexample, even if a filter specified by a Route rule is invalid, the rest\nof the rules within that Route should still be supported.\n\nSupport: Core";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutes")
          );
        };
        "hostname" = mkOption {
          description = "Hostname specifies the virtual hostname to match for protocol types that\ndefine this concept. When unspecified, all hostnames are matched. This\nfield is ignored for protocols that don't require hostname based\nmatching.\n\nImplementations MUST apply Hostname matching appropriately for each of\nthe following protocols:\n\n* TLS: The Listener Hostname MUST match the SNI.\n* HTTP: The Listener Hostname MUST match the Host header of the request.\n* HTTPS: The Listener Hostname SHOULD match both the SNI and Host header.\n  Note that this does not require the SNI and Host header to be the same.\n  The semantics of this are described in more detail below.\n\nTo ensure security, Section 11.1 of RFC-6066 emphasizes that server\nimplementations that rely on SNI hostname matching MUST also verify\nhostnames within the application protocol.\n\nSection 9.1.2 of RFC-7540 provides a mechanism for servers to reject the\nreuse of a connection by responding with the HTTP 421 Misdirected Request\nstatus code. This indicates that the origin server has rejected the\nrequest because it appears to have been misdirected.\n\nTo detect misdirected requests, Gateways SHOULD match the authority of\nthe requests with all the SNI hostname(s) configured across all the\nGateway Listeners on the same port and protocol:\n\n* If another Listener has an exact match or more specific wildcard entry,\n  the Gateway SHOULD return a 421.\n* If the current Listener (selected by SNI matching during ClientHello)\n  does not match the Host:\n    * If another Listener does match the Host the Gateway SHOULD return a\n      421.\n    * If no other Listener matches the Host, the Gateway MUST return a\n      404.\n\nFor HTTPRoute and TLSRoute resources, there is an interaction with the\n`spec.hostnames` array. When both listener and route specify hostnames,\nthere MUST be an intersection between the values for a Route to be\naccepted. For more information, refer to the Route specific Hostnames\ndocumentation.\n\nHostnames that are prefixed with a wildcard label (`*.`) are interpreted\nas a suffix match. That means that a match for `*.example.com` would match\nboth `test.example.com`, and `foo.test.example.com`, but not `example.com`.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the Listener. This name MUST be unique within a\nGateway.\n\nSupport: Core";
          type = types.str;
        };
        "port" = mkOption {
          description = "Port is the network port. Multiple listeners may use the\nsame port, subject to the Listener compatibility rules.\n\nSupport: Core";
          type = types.int;
        };
        "protocol" = mkOption {
          description = "Protocol specifies the network protocol this listener expects to receive.\n\nSupport: Core";
          type = types.str;
        };
        "tls" = mkOption {
          description = "TLS is the TLS configuration for the Listener. This field is required if\nthe Protocol field is \"HTTPS\" or \"TLS\". It is invalid to set this field\nif the Protocol field is \"HTTP\", \"TCP\", or \"UDP\".\n\nThe association of SNIs to Certificate defined in ListenerTLSConfig is\ndefined based on the Hostname field for this listener.\n\nThe GatewayClass MUST use the longest matching SNI out of all\navailable certificates for any TLS handshake.\n\nSupport: Core";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersTls"));
        };
      };

      config = {
        "allowedRoutes" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutes" = {

      options = {
        "kinds" = mkOption {
          description = "Kinds specifies the groups and kinds of Routes that are allowed to bind\nto this Gateway Listener. When unspecified or empty, the kinds of Routes\nselected are determined using the Listener protocol.\n\nA RouteGroupKind MUST correspond to kinds of Routes that are compatible\nwith the application protocol specified in the Listener's Protocol field.\nIf an implementation does not support or recognize this resource type, it\nMUST set the \"ResolvedRefs\" condition to False for this Listener with the\n\"InvalidRouteKinds\" reason.\n\nSupport: Core";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesKinds"
              )
            )
          );
        };
        "namespaces" = mkOption {
          description = "Namespaces indicates namespaces from which Routes may be attached to this\nListener. This is restricted to the namespace of this Gateway by default.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespaces"
            )
          );
        };
      };

      config = {
        "kinds" = mkOverride 1002 null;
        "namespaces" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesKinds" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the Route.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the kind of the Route.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespaces" = {

      options = {
        "from" = mkOption {
          description = "From indicates where Routes will be selected for this Gateway. Possible\nvalues are:\n\n* All: Routes in all namespaces may be used by this Gateway.\n* Selector: Routes in namespaces selected by the selector may be used by\n  this Gateway.\n* Same: Only Routes in the same namespace may be used by this Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "Selector must be specified when From is set to \"Selector\". In that case,\nonly Routes in Namespaces matching this Selector will be selected by this\nGateway. This field is ignored for other values of \"From\".\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespacesSelector"
            )
          );
        };
      };

      config = {
        "from" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespacesSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespacesSelectorMatchExpressions"
              )
            )
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersAllowedRoutesNamespacesSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersTls" = {

      options = {
        "certificateRefs" = mkOption {
          description = "CertificateRefs contains a series of references to Kubernetes objects that\ncontains TLS certificates and private keys. These certificates are used to\nestablish a TLS handshake for requests that match the hostname of the\nassociated listener.\n\nA single CertificateRef to a Kubernetes Secret has \"Core\" support.\nImplementations MAY choose to support attaching multiple certificates to\na Listener, but this behavior is implementation-specific.\n\nReferences to a resource in different namespace are invalid UNLESS there\nis a ReferenceGrant in the target namespace that allows the certificate\nto be attached. If a ReferenceGrant does not allow this reference, the\n\"ResolvedRefs\" condition MUST be set to False for this listener with the\n\"RefNotPermitted\" reason.\n\nThis field is required to have at least one element when the mode is set\nto \"Terminate\" (default) and is optional otherwise.\n\nCertificateRefs can reference to standard Kubernetes resources, i.e.\nSecret, or implementation-specific custom resources.\n\nSupport: Core - A single reference to a Kubernetes Secret of type kubernetes.io/tls\n\nSupport: Implementation-specific (More than one reference or other resource types)";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersTlsCertificateRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "mode" = mkOption {
          description = "Mode defines the TLS behavior for the TLS session initiated by the client.\nThere are two possible modes:\n\n- Terminate: The TLS session between the downstream client and the\n  Gateway is terminated at the Gateway. This mode requires certificates\n  to be specified in some way, such as populating the certificateRefs\n  field.\n- Passthrough: The TLS session is NOT terminated by the Gateway. This\n  implies that the Gateway can't decipher the TLS stream except for\n  the ClientHello message of the TLS protocol. The certificateRefs field\n  is ignored in this mode.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "options" = mkOption {
          description = "Options are a list of key/value pairs to enable extended TLS\nconfiguration for each implementation. For example, configuring the\nminimum TLS version or supported cipher suites.\n\nA set of common keys MAY be defined by the API in the future. To avoid\nany ambiguity, implementation-specific definitions MUST use\ndomain-prefixed names, such as `example.com/my-custom-option`.\nUn-prefixed names are reserved for key names defined by Gateway API.\n\nSupport: Implementation-specific";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "certificateRefs" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewaySpecListenersTlsCertificateRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"Secret\".";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referenced object. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatus" = {

      options = {
        "addresses" = mkOption {
          description = "Addresses lists the network addresses that have been bound to the\nGateway.\n\nThis list may differ from the addresses provided in the spec under some\nconditions:\n\n  * no addresses are specified, all addresses are dynamically assigned\n  * a combination of specified and dynamic addresses are assigned\n  * a specified address was unusable (e.g. already in use)";
          type = (
            types.nullOr (types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayStatusAddresses"))
          );
        };
        "conditions" = mkOption {
          description = "Conditions describe the current conditions of the Gateway.\n\nImplementations should prefer to express Gateway conditions\nusing the `GatewayConditionType` and `GatewayConditionReason`\nconstants so that operators and tools can converge on a common\nvocabulary to describe Gateway state.\n\nKnown condition types are:\n\n* \"Accepted\"\n* \"Programmed\"\n* \"Ready\"";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayStatusConditions")
            )
          );
        };
        "listeners" = mkOption {
          description = "Listeners provide status for each unique listener port defined in the Spec.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.GatewayStatusListeners" "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "addresses" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "listeners" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatusAddresses" = {

      options = {
        "type" = mkOption {
          description = "Type of the address.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value of the address. The validity of the values will depend\non the type and support by the controller.\n\nExamples: `1.2.3.4`, `128::1`, `my-ip-address`.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatusListeners" = {

      options = {
        "attachedRoutes" = mkOption {
          description = "AttachedRoutes represents the total number of Routes that have been\nsuccessfully attached to this Listener.\n\nSuccessful attachment of a Route to a Listener is based solely on the\ncombination of the AllowedRoutes field on the corresponding Listener\nand the Route's ParentRefs field. A Route is successfully attached to\na Listener when it is selected by the Listener's AllowedRoutes field\nAND the Route has a valid ParentRef selecting the whole Gateway\nresource or a specific Listener as a parent resource (more detail on\nattachment semantics can be found in the documentation on the various\nRoute kinds ParentRefs fields). Listener or Route status does not impact\nsuccessful attachment, i.e. the AttachedRoutes field count MUST be set\nfor Listeners with condition Accepted: false and MUST count successfully\nattached Routes that may themselves have Accepted: false conditions.\n\nUses for this field include troubleshooting Route attachment and\nmeasuring blast radius/impact of changes to a Listener.";
          type = types.int;
        };
        "conditions" = mkOption {
          description = "Conditions describe the current condition of this listener.";
          type = (
            types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayStatusListenersConditions")
          );
        };
        "name" = mkOption {
          description = "Name is the name of the Listener that this status corresponds to.";
          type = types.str;
        };
        "supportedKinds" = mkOption {
          description = "SupportedKinds is the list indicating the Kinds supported by this\nlistener. This MUST represent the kinds an implementation supports for\nthat Listener configuration.\n\nIf kinds are specified in Spec that are not supported, they MUST NOT\nappear in this list and an implementation MUST set the \"ResolvedRefs\"\ncondition to \"False\" with the \"InvalidRouteKinds\" reason. If both valid\nand invalid Route kinds are specified, the implementation MUST\nreference the valid Route kinds that have been specified.";
          type = (
            types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.GatewayStatusListenersSupportedKinds")
          );
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatusListenersConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.GatewayStatusListenersSupportedKinds" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the Route.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the kind of the Route.";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRoute" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of HTTPRoute.";
          type = (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpec");
        };
        "status" = mkOption {
          description = "Status defines the current state of HTTPRoute.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpec" = {

      options = {
        "hostnames" = mkOption {
          description = "Hostnames defines a set of hostnames that should match against the HTTP Host\nheader to select a HTTPRoute used to process the request. Implementations\nMUST ignore any port value specified in the HTTP Host header while\nperforming a match and (absent of any applicable header modification\nconfiguration) MUST forward this header unmodified to the backend.\n\nValid values for Hostnames are determined by RFC 1123 definition of a\nhostname with 2 notable exceptions:\n\n1. IPs are not allowed.\n2. A hostname may be prefixed with a wildcard label (`*.`). The wildcard\n   label must appear by itself as the first label.\n\nIf a hostname is specified by both the Listener and HTTPRoute, there\nmust be at least one intersecting hostname for the HTTPRoute to be\nattached to the Listener. For example:\n\n* A Listener with `test.example.com` as the hostname matches HTTPRoutes\n  that have either not specified any hostnames, or have specified at\n  least one of `test.example.com` or `*.example.com`.\n* A Listener with `*.example.com` as the hostname matches HTTPRoutes\n  that have either not specified any hostnames or have specified at least\n  one hostname that matches the Listener hostname. For example,\n  `*.example.com`, `test.example.com`, and `foo.test.example.com` would\n  all match. On the other hand, `example.com` and `test.example.net` would\n  not match.\n\nHostnames that are prefixed with a wildcard label (`*.`) are interpreted\nas a suffix match. That means that a match for `*.example.com` would match\nboth `test.example.com`, and `foo.test.example.com`, but not `example.com`.\n\nIf both the Listener and HTTPRoute have specified hostnames, any\nHTTPRoute hostnames that do not match the Listener hostname MUST be\nignored. For example, if a Listener specified `*.example.com`, and the\nHTTPRoute specified `test.example.com` and `test.example.net`,\n`test.example.net` must not be considered for a match.\n\nIf both the Listener and HTTPRoute have specified hostnames, and none\nmatch with the criteria above, then the HTTPRoute is not accepted. The\nimplementation must raise an 'Accepted' Condition with a status of\n`False` in the corresponding RouteParentStatus.\n\nIn the event that multiple HTTPRoutes specify intersecting hostnames (e.g.\noverlapping wildcard matching and exact matching hostnames), precedence must\nbe given to rules from the HTTPRoute with the largest number of:\n\n* Characters in a matching non-wildcard hostname.\n* Characters in a matching hostname.\n\nIf ties exist across multiple Routes, the matching precedence rules for\nHTTPRouteMatches takes over.\n\nSupport: Core";
          type = (types.nullOr (types.listOf types.str));
        };
        "parentRefs" = mkOption {
          description = "ParentRefs references the resources (usually Gateways) that a Route wants\nto be attached to. Note that the referenced parent resource needs to\nallow this for the attachment to be complete. For Gateways, that means\nthe Gateway needs to allow attachment from Routes of this kind and\nnamespace. For Services, that means the Service must either be in the same\nnamespace for a \"producer\" route, or the mesh implementation must support\nand allow \"consumer\" routes for the referenced Service. ReferenceGrant is\nnot applicable for governing ParentRefs to Services - it is not possible to\ncreate a \"producer\" route for a Service in a different namespace from the\nRoute.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nThis API may be extended in the future to support additional kinds of parent\nresources.\n\nParentRefs must be _distinct_. This means either that:\n\n* They select different objects.  If this is the case, then parentRef\n  entries are distinct. In terms of fields, this means that the\n  multi-part key defined by `group`, `kind`, `namespace`, and `name` must\n  be unique across all parentRef entries in the Route.\n* They do not select different objects, but for each optional field used,\n  each ParentRef that selects the same object must set the same set of\n  optional fields to different values. If one ParentRef sets a\n  combination of optional fields, all must set the same combination.\n\nSome examples:\n\n* If one ParentRef sets `sectionName`, all ParentRefs referencing the\n  same object must also set `sectionName`.\n* If one ParentRef sets `port`, all ParentRefs referencing the same\n  object must also set `port`.\n* If one ParentRef sets `sectionName` and `port`, all ParentRefs\n  referencing the same object must also set `sectionName` and `port`.\n\nIt is possible to separately reference multiple distinct objects that may\nbe collapsed by an implementation. For example, some implementations may\nchoose to merge compatible Gateway Listeners together. If that is the\ncase, the list of routes attached to those resources should also be\nmerged.\n\nNote that for ParentRefs that cross namespace boundaries, there are specific\nrules. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example,\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable other kinds of cross-namespace reference.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecParentRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "rules" = mkOption {
          description = "Rules are a list of HTTP matchers, filters and actions.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRules" "name" [ ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "hostnames" = mkOverride 1002 null;
        "parentRefs" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecParentRefs" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRules" = {

      options = {
        "backendRefs" = mkOption {
          description = "BackendRefs defines the backend(s) where matching requests should be\nsent.\n\nFailure behavior here depends on how many BackendRefs are specified and\nhow many are invalid.\n\nIf *all* entries in BackendRefs are invalid, and there are also no filters\nspecified in this route rule, *all* traffic which matches this rule MUST\nreceive a 500 status code.\n\nSee the HTTPBackendRef definition for the rules about what makes a single\nHTTPBackendRef invalid.\n\nWhen a HTTPBackendRef is invalid, 500 status codes MUST be returned for\nrequests that would have otherwise been routed to an invalid backend. If\nmultiple backends are specified, and some are invalid, the proportion of\nrequests that would otherwise have been routed to an invalid backend\nMUST receive a 500 status code.\n\nFor example, if two backends are specified with equal weights, and one is\ninvalid, 50 percent of traffic must receive a 500. Implementations may\nchoose how that 50 percent is determined.\n\nWhen a HTTPBackendRef refers to a Service that has no ready endpoints,\nimplementations SHOULD return a 503 for requests to that backend instead.\nIf an implementation chooses to do this, all of the above rules for 500 responses\nMUST also apply for responses that return a 503.\n\nSupport: Core for Kubernetes Service\n\nSupport: Extended for Kubernetes ServiceImport\n\nSupport: Implementation-specific for any other resource\n\nSupport for weight: Core";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefs"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "filters" = mkOption {
          description = "Filters define the filters that are applied to requests that match\nthis rule.\n\nWherever possible, implementations SHOULD implement filters in the order\nthey are specified.\n\nImplementations MAY choose to implement this ordering strictly, rejecting\nany combination or order of filters that cannot be supported. If implementations\nchoose a strict interpretation of filter ordering, they MUST clearly document\nthat behavior.\n\nTo reject an invalid combination or order of filters, implementations SHOULD\nconsider the Route Rules with this configuration invalid. If all Route Rules\nin a Route are invalid, the entire Route would be considered invalid. If only\na portion of Route Rules are invalid, implementations MUST set the\n\"PartiallyInvalid\" condition for the Route.\n\nConformance-levels at this level are defined based on the type of filter:\n\n- ALL core filters MUST be supported by all implementations.\n- Implementers are encouraged to support extended filters.\n- Implementation-specific custom filters have no API guarantees across\n  implementations.\n\nSpecifying the same filter multiple times is not supported unless explicitly\nindicated in the filter.\n\nAll filters are expected to be compatible with each other except for the\nURLRewrite and RequestRedirect filters, which may not be combined. If an\nimplementation cannot support other combinations of filters, they must clearly\ndocument that limitation. In cases where incompatible or unsupported\nfilters are specified and cause the `Accepted` condition to be set to status\n`False`, implementations may use the `IncompatibleFilters` reason to specify\nthis configuration error.\n\nSupport: Core";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFilters")
            )
          );
        };
        "matches" = mkOption {
          description = "Matches define conditions used for matching the rule against incoming\nHTTP requests. Each match is independent, i.e. this rule will be matched\nif **any** one of the matches is satisfied.\n\nFor example, take the following matches configuration:\n\n```\nmatches:\n- path:\n    value: \"/foo\"\n  headers:\n  - name: \"version\"\n    value: \"v2\"\n- path:\n    value: \"/v2/foo\"\n```\n\nFor a request to match against this rule, a request must satisfy\nEITHER of the two conditions:\n\n- path prefixed with `/foo` AND contains the header `version: v2`\n- path prefix of `/v2/foo`\n\nSee the documentation for HTTPRouteMatch on how to specify multiple\nmatch conditions that should be ANDed together.\n\nIf no matches are specified, the default is a prefix\npath match on \"/\", which has the effect of matching every\nHTTP request.\n\nProxy or Load Balancer routing configuration generated from HTTPRoutes\nMUST prioritize matches based on the following criteria, continuing on\nties. Across all rules specified on applicable Routes, precedence must be\ngiven to the match having:\n\n* \"Exact\" path match.\n* \"Prefix\" path match with largest number of characters.\n* Method match.\n* Largest number of header matches.\n* Largest number of query param matches.\n\nNote: The precedence of RegularExpression path matches are implementation-specific.\n\nIf ties still exist across multiple Routes, matching precedence MUST be\ndetermined in order of the following criteria, continuing on ties:\n\n* The oldest Route based on creation timestamp.\n* The Route appearing first in alphabetical order by\n  \"{namespace}/{name}\".\n\nIf ties still exist within an HTTPRoute, matching precedence MUST be granted\nto the FIRST matching rule (in list order) with a match meeting the above\ncriteria.\n\nWhen no rules matching a request have been successfully attached to the\nparent a request is coming from, a HTTP 404 status code MUST be returned.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatches")
            )
          );
        };
        "name" = mkOption {
          description = "Name is the name of the route rule. This name MUST be unique within a Route if it is set.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "timeouts" = mkOption {
          description = "Timeouts defines the timeouts that can be configured for an HTTP request.\n\nSupport: Extended";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesTimeouts"));
        };
      };

      config = {
        "backendRefs" = mkOverride 1002 null;
        "filters" = mkOverride 1002 null;
        "matches" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "timeouts" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefs" = {

      options = {
        "filters" = mkOption {
          description = "Filters defined at this level should be executed if and only if the\nrequest is being forwarded to the backend defined here.\n\nSupport: Implementation-specific (For broader support of filters, use the\nFilters field in HTTPRouteRule.)";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFilters")
            )
          );
        };
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
        "weight" = mkOption {
          description = "Weight specifies the proportion of requests forwarded to the referenced\nbackend. This is computed as weight/(sum of all weights in this\nBackendRefs list). For non-zero values, there may be some epsilon from\nthe exact proportion defined here depending on the precision an\nimplementation supports. Weight is not a percentage and the sum of\nweights does not need to equal 100.\n\nIf only one backend is specified and it has a weight greater than 0, 100%\nof the traffic is forwarded to that backend. If weight is set to 0, no\ntraffic should be forwarded for this entry. If unspecified, weight\ndefaults to 1.\n\nSupport for this field varies based on the context where used.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "filters" = mkOverride 1002 null;
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nThis filter can be used multiple times within the same rule.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersExtensionRef"
            )
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirror"
            )
          );
        };
        "requestRedirect" = mkOption {
          description = "RequestRedirect defines a schema for a filter that responds to the\nrequest with an HTTP redirection.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirect"
            )
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations must support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by\n  specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` should be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
        "urlRewrite" = mkOption {
          description = "URLRewrite defines a schema for a filter that modifies a request during forwarding.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewrite"
            )
          );
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "requestRedirect" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
        "urlRewrite" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirect" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the hostname to be used in the value of the `Location`\nheader in the response.\nWhen empty, the hostname in the `Host` header of the request is used.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines parameters used to modify the path of the incoming request.\nThe modified path is then used to construct the `Location` header. When\nempty, the request path is used as-is.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirectPath"
            )
          );
        };
        "port" = mkOption {
          description = "Port is the port to be used in the value of the `Location`\nheader in the response.\n\nIf no port is specified, the redirect port MUST be derived using the\nfollowing rules:\n\n* If redirect scheme is not-empty, the redirect port MUST be the well-known\n  port associated with the redirect scheme. Specifically \"http\" to port 80\n  and \"https\" to port 443. If the redirect scheme does not have a\n  well-known port, the listener port of the Gateway SHOULD be used.\n* If redirect scheme is empty, the redirect port MUST be the Gateway\n  Listener port.\n\nImplementations SHOULD NOT add the port number in the 'Location'\nheader in the following cases:\n\n* A Location header that will use HTTP (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 80.\n* A Location header that will use HTTPS (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 443.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "scheme" = mkOption {
          description = "Scheme is the scheme to be used in the value of the `Location` header in\nthe response. When empty, the scheme of the request is used.\n\nScheme redirects can affect the port of the redirect, for more information,\nrefer to the documentation for the port field of this filter.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "statusCode" = mkOption {
          description = "StatusCode is the HTTP status code to be used in response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Core";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "statusCode" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersRequestRedirectPath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierAdd" =
      {

        options = {
          "name" = mkOption {
            description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
            type = types.str;
          };
          "value" = mkOption {
            description = "Value is the value of HTTP Header to be matched.";
            type = types.str;
          };
        };

        config = { };

      };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersResponseHeaderModifierSet" =
      {

        options = {
          "name" = mkOption {
            description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
            type = types.str;
          };
          "value" = mkOption {
            description = "Value is the value of HTTP Header to be matched.";
            type = types.str;
          };
        };

        config = { };

      };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewrite" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the value to be used to replace the Host header value during\nforwarding.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines a path rewrite.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewritePath"
            )
          );
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesBackendRefsFiltersUrlRewritePath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFilters" = {

      options = {
        "extensionRef" = mkOption {
          description = "ExtensionRef is an optional, implementation-specific extension to the\n\"filter\" behavior.  For example, resource \"myroutefilter\" in group\n\"networking.example.net\"). ExtensionRef MUST NOT be used for core and\nextended filters.\n\nThis filter can be used multiple times within the same rule.\n\nSupport: Implementation-specific";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersExtensionRef")
          );
        };
        "requestHeaderModifier" = mkOption {
          description = "RequestHeaderModifier defines a schema for a filter that modifies request\nheaders.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifier"
            )
          );
        };
        "requestMirror" = mkOption {
          description = "RequestMirror defines a schema for a filter that mirrors requests.\nRequests are sent to the specified destination, but responses from\nthat destination are ignored.\n\nThis filter can be used multiple times within the same rule. Note that\nnot all implementations will be able to support mirroring to multiple\nbackends.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirror"
            )
          );
        };
        "requestRedirect" = mkOption {
          description = "RequestRedirect defines a schema for a filter that responds to the\nrequest with an HTTP redirection.\n\nSupport: Core";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestRedirect"
            )
          );
        };
        "responseHeaderModifier" = mkOption {
          description = "ResponseHeaderModifier defines a schema for a filter that modifies response\nheaders.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifier"
            )
          );
        };
        "type" = mkOption {
          description = "Type identifies the type of filter to apply. As with other API fields,\ntypes are classified into three conformance levels:\n\n- Core: Filter types and their corresponding configuration defined by\n  \"Support: Core\" in this package, e.g. \"RequestHeaderModifier\". All\n  implementations must support core filters.\n\n- Extended: Filter types and their corresponding configuration defined by\n  \"Support: Extended\" in this package, e.g. \"RequestMirror\". Implementers\n  are encouraged to support extended filters.\n\n- Implementation-specific: Filters that are defined and supported by\n  specific vendors.\n  In the future, filters showing convergence in behavior across multiple\n  implementations will be considered for inclusion in extended or core\n  conformance levels. Filter-specific configuration for such filters\n  is specified using the ExtensionRef field. `Type` should be set to\n  \"ExtensionRef\" for custom filters.\n\nImplementers are encouraged to define custom implementation types to\nextend the core API with implementation-specific behavior.\n\nIf a reference to a custom filter type cannot be resolved, the filter\nMUST NOT be skipped. Instead, requests that would have been processed by\nthat filter MUST receive a HTTP error response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
        "urlRewrite" = mkOption {
          description = "URLRewrite defines a schema for a filter that modifies a request during forwarding.\n\nSupport: Extended";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersUrlRewrite")
          );
        };
      };

      config = {
        "extensionRef" = mkOverride 1002 null;
        "requestHeaderModifier" = mkOverride 1002 null;
        "requestMirror" = mkOverride 1002 null;
        "requestRedirect" = mkOverride 1002 null;
        "responseHeaderModifier" = mkOverride 1002 null;
        "urlRewrite" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersExtensionRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent. For example \"HTTPRoute\" or \"Service\".";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirror" = {

      options = {
        "backendRef" = mkOption {
          description = "BackendRef references a resource where mirrored requests are sent.\n\nMirrored requests must be sent only to a single destination endpoint\nwithin this BackendRef, irrespective of how many endpoints are present\nwithin this BackendRef.\n\nIf the referent cannot be found, this BackendRef is invalid and must be\ndropped from the Gateway. The controller must ensure the \"ResolvedRefs\"\ncondition on the Route status is set to `status: False` and not configure\nthis backend in the underlying implementation.\n\nIf there is a cross-namespace reference to an *existing* object\nthat is not allowed by a ReferenceGrant, the controller must ensure the\n\"ResolvedRefs\"  condition on the Route is set to `status: False`,\nwith the \"RefNotPermitted\" reason and not configure this backend in the\nunderlying implementation.\n\nIn either error case, the Message of the `ResolvedRefs` Condition\nshould be used to provide more detail about the problem.\n\nSupport: Extended for Kubernetes Service\n\nSupport: Implementation-specific for any other resource";
          type = (
            submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirrorBackendRef"
          );
        };
        "fraction" = mkOption {
          description = "Fraction represents the fraction of requests that should be\nmirrored to BackendRef.\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirrorFraction"
            )
          );
        };
        "percent" = mkOption {
          description = "Percent represents the percentage of requests that should be\nmirrored to BackendRef. Its minimum value is 0 (indicating 0% of\nrequests) and its maximum value is 100 (indicating 100% of requests).\n\nOnly one of Fraction or Percent may be specified. If neither field\nis specified, 100% of requests will be mirrored.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "fraction" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirrorBackendRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent. For example, \"gateway.networking.k8s.io\".\nWhen unspecified or empty string, core API group is inferred.";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is the Kubernetes resource kind of the referent. For example\n\"Service\".\n\nDefaults to \"Service\" when not specified.\n\nExternalName services can refer to CNAME DNS records that may live\noutside of the cluster and as such are difficult to reason about in\nterms of conformance. They also may not be safe to forward to (see\nCVE-2021-25740 for more information). Implementations SHOULD NOT\nsupport ExternalName Services.\n\nSupport: Core (Services with a type other than ExternalName)\n\nSupport: Implementation-specific (Services with type ExternalName)";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the backend. When unspecified, the local\nnamespace is inferred.\n\nNote that when a namespace different than the local namespace is specified,\na ReferenceGrant object is required in the referent namespace to allow that\nnamespace's owner to accept the reference. See the ReferenceGrant\ndocumentation for details.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port specifies the destination port number to use for this resource.\nPort is required when the referent is a Kubernetes Service. In this\ncase, the port number is the service port number, not the target port.\nFor other resources, destination port might be derived from the referent\nresource or this field.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestMirrorFraction" = {

      options = {
        "denominator" = mkOption {
          description = "";
          type = (types.nullOr types.int);
        };
        "numerator" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "denominator" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestRedirect" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the hostname to be used in the value of the `Location`\nheader in the response.\nWhen empty, the hostname in the `Host` header of the request is used.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines parameters used to modify the path of the incoming request.\nThe modified path is then used to construct the `Location` header. When\nempty, the request path is used as-is.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestRedirectPath"
            )
          );
        };
        "port" = mkOption {
          description = "Port is the port to be used in the value of the `Location`\nheader in the response.\n\nIf no port is specified, the redirect port MUST be derived using the\nfollowing rules:\n\n* If redirect scheme is not-empty, the redirect port MUST be the well-known\n  port associated with the redirect scheme. Specifically \"http\" to port 80\n  and \"https\" to port 443. If the redirect scheme does not have a\n  well-known port, the listener port of the Gateway SHOULD be used.\n* If redirect scheme is empty, the redirect port MUST be the Gateway\n  Listener port.\n\nImplementations SHOULD NOT add the port number in the 'Location'\nheader in the following cases:\n\n* A Location header that will use HTTP (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 80.\n* A Location header that will use HTTPS (whether that is determined via\n  the Listener protocol or the Scheme field) _and_ use port 443.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "scheme" = mkOption {
          description = "Scheme is the scheme to be used in the value of the `Location` header in\nthe response. When empty, the scheme of the request is used.\n\nScheme redirects can affect the port of the redirect, for more information,\nrefer to the documentation for the port field of this filter.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "statusCode" = mkOption {
          description = "StatusCode is the HTTP status code to be used in response.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.\n\nSupport: Core";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "statusCode" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersRequestRedirectPath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifier" = {

      options = {
        "add" = mkOption {
          description = "Add adds the given header(s) (name, value) to the request\nbefore the action. It appends to any existing values associated\nwith the header name.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  add:\n  - name: \"my-header\"\n    value: \"bar,baz\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: foo,bar,baz";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifierAdd"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "remove" = mkOption {
          description = "Remove the given header(s) from the HTTP request before the action. The\nvalue of Remove is a list of HTTP header names. Note that the header\nnames are case-insensitive (see\nhttps://datatracker.ietf.org/doc/html/rfc2616#section-4.2).\n\nInput:\n  GET /foo HTTP/1.1\n  my-header1: foo\n  my-header2: bar\n  my-header3: baz\n\nConfig:\n  remove: [\"my-header1\", \"my-header3\"]\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header2: bar";
          type = (types.nullOr (types.listOf types.str));
        };
        "set" = mkOption {
          description = "Set overwrites the request with the given header (name, value)\nbefore the action.\n\nInput:\n  GET /foo HTTP/1.1\n  my-header: foo\n\nConfig:\n  set:\n  - name: \"my-header\"\n    value: \"bar\"\n\nOutput:\n  GET /foo HTTP/1.1\n  my-header: bar";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifierSet"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "remove" = mkOverride 1002 null;
        "set" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifierAdd" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersResponseHeaderModifierSet" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, the first entry with\nan equivalent name MUST be considered for a match. Subsequent entries\nwith an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersUrlRewrite" = {

      options = {
        "hostname" = mkOption {
          description = "Hostname is the value to be used to replace the Host header value during\nforwarding.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path defines a path rewrite.\n\nSupport: Extended";
          type = (
            types.nullOr (
              submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersUrlRewritePath"
            )
          );
        };
      };

      config = {
        "hostname" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesFiltersUrlRewritePath" = {

      options = {
        "replaceFullPath" = mkOption {
          description = "ReplaceFullPath specifies the value with which to replace the full path\nof a request during a rewrite or redirect.";
          type = (types.nullOr types.str);
        };
        "replacePrefixMatch" = mkOption {
          description = "ReplacePrefixMatch specifies the value with which to replace the prefix\nmatch of a request during a rewrite or redirect. For example, a request\nto \"/foo/bar\" with a prefix match of \"/foo\" and a ReplacePrefixMatch\nof \"/xyz\" would be modified to \"/xyz/bar\".\n\nNote that this matches the behavior of the PathPrefix match type. This\nmatches full path elements. A path element refers to the list of labels\nin the path split by the `/` separator. When specified, a trailing `/` is\nignored. For example, the paths `/abc`, `/abc/`, and `/abc/def` would all\nmatch the prefix `/abc`, but the path `/abcd` would not.\n\nReplacePrefixMatch is only compatible with a `PathPrefix` HTTPRouteMatch.\nUsing any other HTTPRouteMatch type on the same HTTPRouteRule will result in\nthe implementation setting the Accepted Condition for the Route to `status: False`.\n\nRequest Path | Prefix Match | Replace Prefix | Modified Path";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type defines the type of path modifier. Additional types may be\nadded in a future release of the API.\n\nNote that values may be added to this enum, implementations\nmust ensure that unknown values will not cause a crash.\n\nUnknown values here must result in the implementation setting the\nAccepted Condition for the Route to `status: False`, with a\nReason of `UnsupportedValue`.";
          type = types.str;
        };
      };

      config = {
        "replaceFullPath" = mkOverride 1002 null;
        "replacePrefixMatch" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatches" = {

      options = {
        "headers" = mkOption {
          description = "Headers specifies HTTP request header matchers. Multiple match values are\nANDed together, meaning, a request must match all the specified headers\nto select the route.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesHeaders"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "method" = mkOption {
          description = "Method specifies HTTP method matcher.\nWhen specified, this route will be matched only if the request has the\nspecified method.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path specifies a HTTP request path matcher. If this field is not\nspecified, a default prefix match on the \"/\" path is provided.";
          type = (
            types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesPath")
          );
        };
        "queryParams" = mkOption {
          description = "QueryParams specifies HTTP query parameter matchers. Multiple match\nvalues are ANDed together, meaning, a request must match all the\nspecified query parameters to select the route.\n\nSupport: Extended";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesQueryParams"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "headers" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "queryParams" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesHeaders" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP Header to be matched. Name matching MUST be\ncase-insensitive. (See https://tools.ietf.org/html/rfc7230#section-3.2).\n\nIf multiple entries specify equivalent header names, only the first\nentry with an equivalent name MUST be considered for a match. Subsequent\nentries with an equivalent header name MUST be ignored. Due to the\ncase-insensitivity of header names, \"foo\" and \"Foo\" are considered\nequivalent.\n\nWhen a header is repeated in an HTTP request, it is\nimplementation-specific behavior as to how this is represented.\nGenerally, proxies should follow the guidance from the RFC:\nhttps://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.2 regarding\nprocessing a repeated header, with special handling for \"Set-Cookie\".";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type specifies how to match against the value of the header.\n\nSupport: Core (Exact)\n\nSupport: Implementation-specific (RegularExpression)\n\nSince RegularExpression HeaderMatchType has implementation-specific\nconformance, implementations can support POSIX, PCRE or any other dialects\nof regular expressions. Please read the implementation's documentation to\ndetermine the supported dialect.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value is the value of HTTP Header to be matched.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesPath" = {

      options = {
        "type" = mkOption {
          description = "Type specifies how to match against the path Value.\n\nSupport: Core (Exact, PathPrefix)\n\nSupport: Implementation-specific (RegularExpression)";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value of the HTTP path to match against.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "type" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesMatchesQueryParams" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the HTTP query param to be matched. This must be an\nexact string match. (See\nhttps://tools.ietf.org/html/rfc7230#section-2.7.3).\n\nIf multiple entries specify equivalent query param names, only the first\nentry with an equivalent name MUST be considered for a match. Subsequent\nentries with an equivalent query param name MUST be ignored.\n\nIf a query param is repeated in an HTTP request, the behavior is\npurposely left undefined, since different data planes have different\ncapabilities. However, it is *recommended* that implementations should\nmatch against the first value of the param if the data plane supports it,\nas this behavior is expected in other load balancing contexts outside of\nthe Gateway API.\n\nUsers SHOULD NOT route traffic based on repeated query params to guard\nthemselves against potential differences in the implementations.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type specifies how to match against the value of the query parameter.\n\nSupport: Extended (Exact)\n\nSupport: Implementation-specific (RegularExpression)\n\nSince RegularExpression QueryParamMatchType has Implementation-specific\nconformance, implementations can support POSIX, PCRE or any other\ndialects of regular expressions. Please read the implementation's\ndocumentation to determine the supported dialect.";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "Value is the value of HTTP query param to be matched.";
          type = types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteSpecRulesTimeouts" = {

      options = {
        "backendRequest" = mkOption {
          description = "BackendRequest specifies a timeout for an individual request from the gateway\nto a backend. This covers the time from when the request first starts being\nsent from the gateway to when the full response has been received from the backend.\n\nSetting a timeout to the zero duration (e.g. \"0s\") SHOULD disable the timeout\ncompletely. Implementations that cannot completely disable the timeout MUST\ninstead interpret the zero duration as the longest possible value to which\nthe timeout can be set.\n\nAn entire client HTTP transaction with a gateway, covered by the Request timeout,\nmay result in more than one call from the gateway to the destination backend,\nfor example, if automatic retries are supported.\n\nThe value of BackendRequest must be a Gateway API Duration string as defined by\nGEP-2257.  When this field is unspecified, its behavior is implementation-specific;\nwhen specified, the value of BackendRequest must be no more than the value of the\nRequest timeout (since the Request timeout encompasses the BackendRequest timeout).\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
        "request" = mkOption {
          description = "Request specifies the maximum duration for a gateway to respond to an HTTP request.\nIf the gateway has not been able to respond before this deadline is met, the gateway\nMUST return a timeout error.\n\nFor example, setting the `rules.timeouts.request` field to the value `10s` in an\n`HTTPRoute` will cause a timeout if a client request is taking longer than 10 seconds\nto complete.\n\nSetting a timeout to the zero duration (e.g. \"0s\") SHOULD disable the timeout\ncompletely. Implementations that cannot completely disable the timeout MUST\ninstead interpret the zero duration as the longest possible value to which\nthe timeout can be set.\n\nThis timeout is intended to cover as close to the whole request-response transaction\nas possible although an implementation MAY choose to start the timeout after the entire\nrequest stream has been received instead of immediately after the transaction is\ninitiated by the client.\n\nThe value of Request is a Gateway API Duration string as defined by GEP-2257. When this\nfield is unspecified, request timeout behavior is implementation-specific.\n\nSupport: Extended";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "backendRequest" = mkOverride 1002 null;
        "request" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteStatus" = {

      options = {
        "parents" = mkOption {
          description = "Parents is a list of parent resources (usually Gateways) that are\nassociated with the route, and the status of the route with respect to\neach parent. When this route attaches to a parent, the controller that\nmanages the parent must add an entry to this list when the controller\nfirst sees the route and should update the entry as appropriate when the\nroute or gateway is modified.\n\nNote that parent references that cannot be resolved by an implementation\nof this API will not be added to this list. Implementations of this API\ncan only populate Route status for the Gateways/parent resources they are\nresponsible for.\n\nA maximum of 32 Gateways will be represented in this list. An empty list\nmeans the route has not been attached to any Gateway.";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParents"));
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParents" = {

      options = {
        "conditions" = mkOption {
          description = "Conditions describes the status of the route with respect to the Gateway.\nNote that the route's availability is also subject to the Gateway's own\nstatus conditions and listener status.\n\nIf the Route's ParentRef specifies an existing Gateway that supports\nRoutes of this kind AND that Gateway's controller has sufficient access,\nthen that Gateway's controller MUST set the \"Accepted\" condition on the\nRoute, to indicate whether the route has been accepted or rejected by the\nGateway, and why.\n\nA Route MUST be considered \"Accepted\" if at least one of the Route's\nrules is implemented by the Gateway.\n\nThere are a number of cases where the \"Accepted\" condition may not be set\ndue to lack of controller visibility, that includes when:\n\n* The Route refers to a nonexistent parent.\n* The Route is of a type that the controller does not support.\n* The Route is in a namespace the controller does not have access to.";
          type = (
            types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParentsConditions")
          );
        };
        "controllerName" = mkOption {
          description = "ControllerName is a domain/path string that indicates the name of the\ncontroller that wrote this status. This corresponds with the\ncontrollerName field on GatewayClass.\n\nExample: \"example.net/gateway-controller\".\n\nThe format of this field is DOMAIN \"/\" PATH, where DOMAIN and PATH are\nvalid Kubernetes names\n(https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names).\n\nControllers MUST populate this field when writing status. Controllers should ensure that\nentries to status populated with their ControllerName are cleaned up when they are no\nlonger necessary.";
          type = types.str;
        };
        "parentRef" = mkOption {
          description = "ParentRef corresponds with a ParentRef in the spec that this\nRouteParentStatus struct describes the status of.";
          type = (submoduleOf "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParentsParentRef");
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParentsConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.HTTPRouteStatusParentsParentRef" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen unspecified, \"gateway.networking.k8s.io\" is inferred.\nTo set the core API group (such as for a \"Service\" kind referent),\nGroup must be explicitly set to \"\" (empty string).\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is kind of the referent.\n\nThere are two kinds of parent resources with \"Core\" support:\n\n* Gateway (Gateway conformance profile)\n* Service (Mesh conformance profile, ClusterIP Services only)\n\nSupport for other resources is Implementation-Specific.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the name of the referent.\n\nSupport: Core";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent. When unspecified, this refers\nto the local namespace of the Route.\n\nNote that there are specific rules for ParentRefs which cross namespace\nboundaries. Cross-namespace references are only valid if they are explicitly\nallowed by something in the namespace they are referring to. For example:\nGateway has the AllowedRoutes field, and ReferenceGrant provides a\ngeneric way to enable any other kind of cross-namespace reference.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
        "port" = mkOption {
          description = "Port is the network port this Route targets. It can be interpreted\ndifferently based on the type of parent resource.\n\nWhen the parent resource is a Gateway, this targets all listeners\nlistening on the specified port that also support this kind of Route(and\nselect this Route). It's not recommended to set `Port` unless the\nnetworking behaviors specified in a Route must apply to a specific port\nas opposed to a listener(s) whose port(s) may be changed. When both Port\nand SectionName are specified, the name and port of the selected listener\nmust match both specified values.\n\nImplementations MAY choose to support other parent resources.\nImplementations supporting other types of parent resources MUST clearly\ndocument how/if Port is interpreted.\n\nFor the purpose of status, an attachment is considered successful as\nlong as the parent resource accepts it partially. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment\nfrom the referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route,\nthe Route MUST be considered detached from the Gateway.\n\nSupport: Extended";
          type = (types.nullOr types.int);
        };
        "sectionName" = mkOption {
          description = "SectionName is the name of a section within the target resource. In the\nfollowing resources, SectionName is interpreted as the following:\n\n* Gateway: Listener name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n* Service: Port name. When both Port (experimental) and SectionName\nare specified, the name and port of the selected listener must match\nboth specified values.\n\nImplementations MAY choose to support attaching Routes to other resources.\nIf that is the case, they MUST clearly document how SectionName is\ninterpreted.\n\nWhen unspecified (empty string), this will reference the entire resource.\nFor the purpose of status, an attachment is considered successful if at\nleast one section in the parent resource accepts it. For example, Gateway\nlisteners can restrict which Routes can attach to them by Route kind,\nnamespace, or hostname. If 1 of 2 Gateway listeners accept attachment from\nthe referencing Route, the Route MUST be considered successfully\nattached. If no Gateway listeners accept attachment from this Route, the\nRoute MUST be considered detached from the Gateway.\n\nSupport: Core";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "sectionName" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.ReferenceGrant" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Spec defines the desired state of ReferenceGrant.";
          type = (types.nullOr (submoduleOf "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpec"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };

    };
    "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpec" = {

      options = {
        "from" = mkOption {
          description = "From describes the trusted namespaces and kinds that can reference the\nresources described in \"To\". Each entry in this list MUST be considered\nto be an additional place that references can be valid from, or to put\nthis another way, entries MUST be combined using OR.\n\nSupport: Core";
          type = (types.listOf (submoduleOf "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpecFrom"));
        };
        "to" = mkOption {
          description = "To describes the resources that may be referenced by the resources\ndescribed in \"From\". Each entry in this list MUST be considered to be an\nadditional place that references can be valid to, or to put this another\nway, entries MUST be combined using OR.\n\nSupport: Core";
          type = (
            coerceAttrsOfSubmodulesToListByKey "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpecTo" "name"
              [ ]
          );
          apply = attrsToList;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpecFrom" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen empty, the Kubernetes core API group is inferred.\n\nSupport: Core";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is the kind of the referent. Although implementations may support\nadditional resources, the following types are part of the \"Core\"\nsupport level for this field.\n\nWhen used to permit a SecretObjectReference:\n\n* Gateway\n\nWhen used to permit a BackendObjectReference:\n\n* GRPCRoute\n* HTTPRoute\n* TCPRoute\n* TLSRoute\n* UDPRoute";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace of the referent.\n\nSupport: Core";
          type = types.str;
        };
      };

      config = { };

    };
    "gateway.networking.k8s.io.v1beta1.ReferenceGrantSpecTo" = {

      options = {
        "group" = mkOption {
          description = "Group is the group of the referent.\nWhen empty, the Kubernetes core API group is inferred.\n\nSupport: Core";
          type = types.str;
        };
        "kind" = mkOption {
          description = "Kind is the kind of the referent. Although implementations may support\nadditional resources, the following types are part of the \"Core\"\nsupport level for this field:\n\n* Secret when used to permit a SecretObjectReference\n* Service when used to permit a BackendObjectReference";
          type = types.str;
        };
        "name" = mkOption {
          description = "Name is the name of the referent. When unspecified, this policy\nrefers to all resources of the specified Group and Kind in the local\nnamespace.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };

  };
in
{
  # all resource versions
  options = {
    resources = {
      "gateway.networking.k8s.io"."v1"."BackendTLSPolicy" = mkOption {
        description = "BackendTLSPolicy provides a way to configure how a Gateway\nconnects to a Backend via TLS.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.BackendTLSPolicy" "backendtlspolicies"
              "BackendTLSPolicy"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1"."GRPCRoute" = mkOption {
        description = "GRPCRoute provides a way to route gRPC requests. This includes the capability\nto match requests by hostname, gRPC service, gRPC method, or HTTP/2 header.\nFilters can be used to specify additional processing steps. Backends specify\nwhere matching requests will be routed.\n\nGRPCRoute falls under extended support within the Gateway API. Within the\nfollowing specification, the word \"MUST\" indicates that an implementation\nsupporting GRPCRoute must conform to the indicated requirement, but an\nimplementation not supporting this route type need not follow the requirement\nunless explicitly indicated.\n\nImplementations supporting `GRPCRoute` with the `HTTPS` `ProtocolType` MUST\naccept HTTP/2 connections without an initial upgrade from HTTP/1.1, i.e. via\nALPN. If the implementation does not support this, then it MUST set the\n\"Accepted\" condition to \"False\" for the affected listener with a reason of\n\"UnsupportedProtocol\".  Implementations MAY also accept HTTP/2 connections\nwith an upgrade from HTTP/1.\n\nImplementations supporting `GRPCRoute` with the `HTTP` `ProtocolType` MUST\nsupport HTTP/2 over cleartext TCP (h2c,\nhttps://www.rfc-editor.org/rfc/rfc7540#section-3.1) without an initial\nupgrade from HTTP/1.1, i.e. with prior knowledge\n(https://www.rfc-editor.org/rfc/rfc7540#section-3.4). If the implementation\ndoes not support this, then it MUST set the \"Accepted\" condition to \"False\"\nfor the affected listener with a reason of \"UnsupportedProtocol\".\nImplementations MAY also accept HTTP/2 connections with an upgrade from\nHTTP/1, i.e. without prior knowledge.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.GRPCRoute" "grpcroutes" "GRPCRoute"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1"."Gateway" = mkOption {
        description = "Gateway represents an instance of a service-traffic handling infrastructure\nby binding Listeners to a set of IP addresses.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.Gateway" "gateways" "Gateway"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1"."GatewayClass" = mkOption {
        description = "GatewayClass describes a class of Gateways available to the user for creating\nGateway resources.\n\nIt is recommended that this resource be used as a template for Gateways. This\nmeans that a Gateway is based on the state of the GatewayClass at the time it\nwas created and changes to the GatewayClass or associated parameters are not\npropagated down to existing Gateways. This recommendation is intended to\nlimit the blast radius of changes to GatewayClass or associated parameters.\nIf implementations choose to propagate GatewayClass changes to existing\nGateways, that MUST be clearly documented by the implementation.\n\nWhenever one or more Gateways are using a GatewayClass, implementations SHOULD\nadd the `gateway-exists-finalizer.gateway.networking.k8s.io` finalizer on the\nassociated GatewayClass. This ensures that a GatewayClass associated with a\nGateway is not deleted while in use.\n\nGatewayClass is a Cluster level resource.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.GatewayClass" "gatewayclasses" "GatewayClass"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1"."HTTPRoute" = mkOption {
        description = "HTTPRoute provides a way to route HTTP requests. This includes the capability\nto match requests by hostname, path, header, or query param. Filters can be\nused to specify additional processing steps. Backends specify where matching\nrequests should be routed.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.HTTPRoute" "httproutes" "HTTPRoute"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1beta1"."Gateway" = mkOption {
        description = "Gateway represents an instance of a service-traffic handling infrastructure\nby binding Listeners to a set of IP addresses.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1beta1.Gateway" "gateways" "Gateway"
              "gateway.networking.k8s.io"
              "v1beta1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1beta1"."GatewayClass" = mkOption {
        description = "GatewayClass describes a class of Gateways available to the user for creating\nGateway resources.\n\nIt is recommended that this resource be used as a template for Gateways. This\nmeans that a Gateway is based on the state of the GatewayClass at the time it\nwas created and changes to the GatewayClass or associated parameters are not\npropagated down to existing Gateways. This recommendation is intended to\nlimit the blast radius of changes to GatewayClass or associated parameters.\nIf implementations choose to propagate GatewayClass changes to existing\nGateways, that MUST be clearly documented by the implementation.\n\nWhenever one or more Gateways are using a GatewayClass, implementations SHOULD\nadd the `gateway-exists-finalizer.gateway.networking.k8s.io` finalizer on the\nassociated GatewayClass. This ensures that a GatewayClass associated with a\nGateway is not deleted while in use.\n\nGatewayClass is a Cluster level resource.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1beta1.GatewayClass" "gatewayclasses"
              "GatewayClass"
              "gateway.networking.k8s.io"
              "v1beta1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1beta1"."HTTPRoute" = mkOption {
        description = "HTTPRoute provides a way to route HTTP requests. This includes the capability\nto match requests by hostname, path, header, or query param. Filters can be\nused to specify additional processing steps. Backends specify where matching\nrequests should be routed.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1beta1.HTTPRoute" "httproutes" "HTTPRoute"
              "gateway.networking.k8s.io"
              "v1beta1"
          )
        );
        default = { };
      };
      "gateway.networking.k8s.io"."v1beta1"."ReferenceGrant" = mkOption {
        description = "ReferenceGrant identifies kinds of resources in other namespaces that are\ntrusted to reference the specified kinds of resources in the same namespace\nas the policy.\n\nEach ReferenceGrant can be used to represent a unique trust relationship.\nAdditional Reference Grants can be used to add to the set of trusted\nsources of inbound references for the namespace they are defined within.\n\nAll cross-namespace references in Gateway API (with the exception of cross-namespace\nGateway-route attachment) require a ReferenceGrant.\n\nReferenceGrant is a form of runtime verification allowing users to assert\nwhich cross-namespace object references are permitted. Implementations that\nsupport ReferenceGrant MUST NOT permit cross-namespace references which have\nno grant, and MUST respond to the removal of a grant by revoking the access\nthat the grant allowed.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1beta1.ReferenceGrant" "referencegrants"
              "ReferenceGrant"
              "gateway.networking.k8s.io"
              "v1beta1"
          )
        );
        default = { };
      };

    }
    // {
      "backendTLSPolicies" = mkOption {
        description = "BackendTLSPolicy provides a way to configure how a Gateway\nconnects to a Backend via TLS.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.BackendTLSPolicy" "backendtlspolicies"
              "BackendTLSPolicy"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "grpcRoutes" = mkOption {
        description = "GRPCRoute provides a way to route gRPC requests. This includes the capability\nto match requests by hostname, gRPC service, gRPC method, or HTTP/2 header.\nFilters can be used to specify additional processing steps. Backends specify\nwhere matching requests will be routed.\n\nGRPCRoute falls under extended support within the Gateway API. Within the\nfollowing specification, the word \"MUST\" indicates that an implementation\nsupporting GRPCRoute must conform to the indicated requirement, but an\nimplementation not supporting this route type need not follow the requirement\nunless explicitly indicated.\n\nImplementations supporting `GRPCRoute` with the `HTTPS` `ProtocolType` MUST\naccept HTTP/2 connections without an initial upgrade from HTTP/1.1, i.e. via\nALPN. If the implementation does not support this, then it MUST set the\n\"Accepted\" condition to \"False\" for the affected listener with a reason of\n\"UnsupportedProtocol\".  Implementations MAY also accept HTTP/2 connections\nwith an upgrade from HTTP/1.\n\nImplementations supporting `GRPCRoute` with the `HTTP` `ProtocolType` MUST\nsupport HTTP/2 over cleartext TCP (h2c,\nhttps://www.rfc-editor.org/rfc/rfc7540#section-3.1) without an initial\nupgrade from HTTP/1.1, i.e. with prior knowledge\n(https://www.rfc-editor.org/rfc/rfc7540#section-3.4). If the implementation\ndoes not support this, then it MUST set the \"Accepted\" condition to \"False\"\nfor the affected listener with a reason of \"UnsupportedProtocol\".\nImplementations MAY also accept HTTP/2 connections with an upgrade from\nHTTP/1, i.e. without prior knowledge.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.GRPCRoute" "grpcroutes" "GRPCRoute"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gateways" = mkOption {
        description = "Gateway represents an instance of a service-traffic handling infrastructure\nby binding Listeners to a set of IP addresses.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.Gateway" "gateways" "Gateway"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "gatewayClasses" = mkOption {
        description = "GatewayClass describes a class of Gateways available to the user for creating\nGateway resources.\n\nIt is recommended that this resource be used as a template for Gateways. This\nmeans that a Gateway is based on the state of the GatewayClass at the time it\nwas created and changes to the GatewayClass or associated parameters are not\npropagated down to existing Gateways. This recommendation is intended to\nlimit the blast radius of changes to GatewayClass or associated parameters.\nIf implementations choose to propagate GatewayClass changes to existing\nGateways, that MUST be clearly documented by the implementation.\n\nWhenever one or more Gateways are using a GatewayClass, implementations SHOULD\nadd the `gateway-exists-finalizer.gateway.networking.k8s.io` finalizer on the\nassociated GatewayClass. This ensures that a GatewayClass associated with a\nGateway is not deleted while in use.\n\nGatewayClass is a Cluster level resource.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.GatewayClass" "gatewayclasses" "GatewayClass"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "httpRoutes" = mkOption {
        description = "HTTPRoute provides a way to route HTTP requests. This includes the capability\nto match requests by hostname, path, header, or query param. Filters can be\nused to specify additional processing steps. Backends specify where matching\nrequests should be routed.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1.HTTPRoute" "httproutes" "HTTPRoute"
              "gateway.networking.k8s.io"
              "v1"
          )
        );
        default = { };
      };
      "referenceGrants" = mkOption {
        description = "ReferenceGrant identifies kinds of resources in other namespaces that are\ntrusted to reference the specified kinds of resources in the same namespace\nas the policy.\n\nEach ReferenceGrant can be used to represent a unique trust relationship.\nAdditional Reference Grants can be used to add to the set of trusted\nsources of inbound references for the namespace they are defined within.\n\nAll cross-namespace references in Gateway API (with the exception of cross-namespace\nGateway-route attachment) require a ReferenceGrant.\n\nReferenceGrant is a form of runtime verification allowing users to assert\nwhich cross-namespace object references are permitted. Implementations that\nsupport ReferenceGrant MUST NOT permit cross-namespace references which have\nno grant, and MUST respond to the removal of a grant by revoking the access\nthat the grant allowed.";
        type = (
          types.attrsOf (
            submoduleForDefinition "gateway.networking.k8s.io.v1beta1.ReferenceGrant" "referencegrants"
              "ReferenceGrant"
              "gateway.networking.k8s.io"
              "v1beta1"
          )
        );
        default = { };
      };

    };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "backendtlspolicies";
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "BackendTLSPolicy";
        attrName = "backendTLSPolicies";
      }
      {
        name = "grpcroutes";
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "GRPCRoute";
        attrName = "grpcRoutes";
      }
      {
        name = "gateways";
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "Gateway";
        attrName = "gateways";
      }
      {
        name = "gatewayclasses";
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "GatewayClass";
        attrName = "gatewayClasses";
      }
      {
        name = "httproutes";
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "HTTPRoute";
        attrName = "httpRoutes";
      }
      {
        name = "gateways";
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "Gateway";
        attrName = "gateways";
      }
      {
        name = "gatewayclasses";
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "GatewayClass";
        attrName = "gatewayClasses";
      }
      {
        name = "httproutes";
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "HTTPRoute";
        attrName = "httpRoutes";
      }
      {
        name = "referencegrants";
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "ReferenceGrant";
        attrName = "referenceGrants";
      }
    ];

    resources = {
      "gateway.networking.k8s.io"."v1"."BackendTLSPolicy" =
        mkAliasDefinitions
          options.resources."backendTLSPolicies";
      "gateway.networking.k8s.io"."v1"."GRPCRoute" = mkAliasDefinitions options.resources."grpcRoutes";
      "gateway.networking.k8s.io"."v1"."Gateway" = mkAliasDefinitions options.resources."gateways";
      "gateway.networking.k8s.io"."v1"."GatewayClass" =
        mkAliasDefinitions
          options.resources."gatewayClasses";
      "gateway.networking.k8s.io"."v1"."HTTPRoute" = mkAliasDefinitions options.resources."httpRoutes";
      "gateway.networking.k8s.io"."v1beta1"."ReferenceGrant" =
        mkAliasDefinitions
          options.resources."referenceGrants";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "BackendTLSPolicy";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "GRPCRoute";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "Gateway";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1";
        kind = "HTTPRoute";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "Gateway";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "HTTPRoute";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "gateway.networking.k8s.io";
        version = "v1beta1";
        kind = "ReferenceGrant";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
