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
    "cilium.io.v2.CiliumBGPAdvertisement" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpec" = {

      options = {
        "advertisements" = mkOption {
          description = "Advertisements is a list of BGP advertisements.";
          type = (types.listOf (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisements"));
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisements" = {

      options = {
        "advertisementType" = mkOption {
          description = "AdvertisementType defines type of advertisement which has to be advertised.";
          type = types.str;
        };
        "attributes" = mkOption {
          description = "Attributes defines additional attributes to set to the advertised routes.\nIf not specified, no additional attributes are set.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsAttributes")
          );
        };
        "interface" = mkOption {
          description = "Interface defines configuration options for the \"Interface\" advertisementType.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsInterface")
          );
        };
        "selector" = mkOption {
          description = "Selector is a label selector to select objects of the type specified by AdvertisementType.\nFor the PodCIDR AdvertisementType it is not applicable. For other advertisement types,\nif not specified, no objects of the type specified by AdvertisementType are selected for advertisement.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsSelector"));
        };
        "service" = mkOption {
          description = "Service defines configuration options for the \"Service\" advertisementType.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsService"));
        };
      };

      config = {
        "attributes" = mkOverride 1002 null;
        "interface" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsAttributes" = {

      options = {
        "communities" = mkOption {
          description = "Communities sets the community attributes in the route.\nIf not specified, no community attribute is set.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsAttributesCommunities"
            )
          );
        };
        "localPreference" = mkOption {
          description = "LocalPreference sets the local preference attribute in the route.\nIf not specified, no local preference attribute is set.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "communities" = mkOverride 1002 null;
        "localPreference" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsAttributesCommunities" = {

      options = {
        "large" = mkOption {
          description = "Large holds a list of the BGP Large Communities Attribute (RFC 8092) values.";
          type = (types.nullOr (types.listOf types.str));
        };
        "standard" = mkOption {
          description = "Standard holds a list of \"standard\" 32-bit BGP Communities Attribute (RFC 1997) values defined as numeric values.";
          type = (types.nullOr (types.listOf types.str));
        };
        "wellKnown" = mkOption {
          description = "WellKnown holds a list \"standard\" 32-bit BGP Communities Attribute (RFC 1997) values defined as\nwell-known string aliases to their numeric values.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "large" = mkOverride 1002 null;
        "standard" = mkOverride 1002 null;
        "wellKnown" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsInterface" = {

      options = {
        "name" = mkOption {
          description = "Name of local interface of whose IP addresses will be advertised via BGP.\nEach IP address applied on the interface is advertised as a /32 prefix (for IPv4) or a /128 prefix (for IPv6).";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumBGPAdvertisementSpecAdvertisementsService" = {

      options = {
        "addresses" = mkOption {
          description = "Addresses is a list of service address types which needs to be advertised via BGP.";
          type = (types.listOf types.str);
        };
        "aggregationLengthIPv4" = mkOption {
          description = "IPv4 mask to aggregate BGP route advertisements of service";
          type = (types.nullOr types.int);
        };
        "aggregationLengthIPv6" = mkOption {
          description = "IPv6 mask to aggregate BGP route advertisements of service";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "aggregationLengthIPv4" = mkOverride 1002 null;
        "aggregationLengthIPv6" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfig" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec defines the desired cluster configuration of the BGP control plane.";
          type = (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpec");
        };
        "status" = mkOption {
          description = "Status is a running status of the cluster configuration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpec" = {

      options = {
        "bgpInstances" = mkOption {
          description = "A list of CiliumBGPInstance(s) which instructs\nthe BGP control plane how to instantiate virtual BGP routers.";
          type = (
            coerceAttrsOfSubmodulesToListByKey "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstances" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects a group of nodes where this BGP Cluster\nconfig applies.\nIf empty / nil this config applies to all nodes.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpecNodeSelector"));
        };
      };

      config = {
        "nodeSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstances" = {

      options = {
        "localASN" = mkOption {
          description = "LocalASN is the ASN of this BGP instance.\nSupports extended 32bit ASNs.";
          type = (types.nullOr types.int);
        };
        "localPort" = mkOption {
          description = "LocalPort is the port on which the BGP daemon listens for incoming connections.\n\nIf not specified, BGP instance will not listen for incoming connections.";
          type = (types.nullOr types.int);
        };
        "name" = mkOption {
          description = "Name is the name of the BGP instance. It is a unique identifier for the BGP instance\nwithin the cluster configuration.";
          type = types.str;
        };
        "peers" = mkOption {
          description = "Peers is a list of neighboring BGP peers for this virtual router";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeers" "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
      };

      config = {
        "localASN" = mkOverride 1002 null;
        "localPort" = mkOverride 1002 null;
        "peers" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeers" = {

      options = {
        "autoDiscovery" = mkOption {
          description = "AutoDiscovery is the configuration for auto-discovery of the peer address.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersAutoDiscovery")
          );
        };
        "name" = mkOption {
          description = "Name is the name of the BGP peer. It is a unique identifier for the peer within the BGP instance.";
          type = types.str;
        };
        "peerASN" = mkOption {
          description = "PeerASN is the ASN of the peer BGP router.\nSupports extended 32bit ASNs.\n\nIf peerASN is 0, the BGP OPEN message validation of ASN will be disabled and\nASN will be determined based on peer's OPEN message.";
          type = (types.nullOr types.int);
        };
        "peerAddress" = mkOption {
          description = "PeerAddress is the IP address of the neighbor.\nSupports IPv4 and IPv6 addresses.";
          type = (types.nullOr types.str);
        };
        "peerConfigRef" = mkOption {
          description = "PeerConfigRef is a reference to a peer configuration resource.\nIf not specified, the default BGP configuration is used for this peer.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersPeerConfigRef")
          );
        };
      };

      config = {
        "autoDiscovery" = mkOverride 1002 null;
        "peerASN" = mkOverride 1002 null;
        "peerAddress" = mkOverride 1002 null;
        "peerConfigRef" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersAutoDiscovery" = {

      options = {
        "defaultGateway" = mkOption {
          description = "defaultGateway is the configuration for auto-discovery of the default gateway.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersAutoDiscoveryDefaultGateway"
            )
          );
        };
        "mode" = mkOption {
          description = "mode is the mode of the auto-discovery.";
          type = types.str;
        };
      };

      config = {
        "defaultGateway" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersAutoDiscoveryDefaultGateway" = {

      options = {
        "addressFamily" = mkOption {
          description = "addressFamily is the address family of the default gateway.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecBgpInstancesPeersPeerConfigRef" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the peer config resource.\nName refers to the name of a Kubernetes object (typically a CiliumBGPPeerConfig).";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumBGPClusterConfigSpecNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigSpecNodeSelectorMatchExpressions")
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
    "cilium.io.v2.CiliumBGPClusterConfigSpecNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumBGPClusterConfigStatus" = {

      options = {
        "conditions" = mkOption {
          description = "The current conditions of the CiliumBGPClusterConfig";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumBGPClusterConfigStatusConditions"))
          );
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPClusterConfigStatusConditions" = {

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
    "cilium.io.v2.CiliumBGPNodeConfigOverride" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is the specification of the desired behavior of the CiliumBGPNodeConfigOverride.";
          type = (submoduleOf "cilium.io.v2.CiliumBGPNodeConfigOverrideSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPNodeConfigOverrideSpec" = {

      options = {
        "bgpInstances" = mkOption {
          description = "BGPInstances is a list of BGP instances to override.";
          type = (
            coerceAttrsOfSubmodulesToListByKey "cilium.io.v2.CiliumBGPNodeConfigOverrideSpecBgpInstances" "name"
              [ "name" ]
          );
          apply = attrsToList;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumBGPNodeConfigOverrideSpecBgpInstances" = {

      options = {
        "localASN" = mkOption {
          description = "LocalASN is the ASN to use for this BGP instance.";
          type = (types.nullOr types.int);
        };
        "localPort" = mkOption {
          description = "LocalPort is port to use for this BGP instance.";
          type = (types.nullOr types.int);
        };
        "name" = mkOption {
          description = "Name is the name of the BGP instance for which the configuration is overridden.";
          type = types.str;
        };
        "peers" = mkOption {
          description = "Peers is a list of peer configurations to override.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "cilium.io.v2.CiliumBGPNodeConfigOverrideSpecBgpInstancesPeers"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "routerID" = mkOption {
          description = "RouterID is BGP router id to use for this instance. It must be unique across all BGP instances.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "localASN" = mkOverride 1002 null;
        "localPort" = mkOverride 1002 null;
        "peers" = mkOverride 1002 null;
        "routerID" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPNodeConfigOverrideSpecBgpInstancesPeers" = {

      options = {
        "localAddress" = mkOption {
          description = "LocalAddress is the IP address to use for connecting to this peer.";
          type = (types.nullOr types.str);
        };
        "localPort" = mkOption {
          description = "LocalPort is source port to use for connecting to this peer.";
          type = (types.nullOr types.int);
        };
        "name" = mkOption {
          description = "Name is the name of the peer for which the configuration is overridden.";
          type = types.str;
        };
      };

      config = {
        "localAddress" = mkOverride 1002 null;
        "localPort" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfig" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is the specification of the desired behavior of the CiliumBGPPeerConfig.";
          type = (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpec");
        };
        "status" = mkOption {
          description = "Status is the running status of the CiliumBGPPeerConfig";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigSpec" = {

      options = {
        "authSecretRef" = mkOption {
          description = "AuthSecretRef is the name of the secret to use to fetch a TCP\nauthentication password for this peer.\n\nIf not specified, no authentication is used.";
          type = (types.nullOr types.str);
        };
        "ebgpMultihop" = mkOption {
          description = "EBGPMultihopTTL controls the multi-hop feature for eBGP peers.\nIts value defines the Time To Live (TTL) value used in BGP\npackets sent to the peer.\n\nIf not specified, EBGP multihop is disabled. This field is ignored for iBGP neighbors.";
          type = (types.nullOr types.int);
        };
        "families" = mkOption {
          description = "Families, if provided, defines a set of AFI/SAFIs the speaker will\nnegotiate with it's peer.\n\nIf not specified, the default families of IPv6/unicast and IPv4/unicast will be created.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecFamilies")));
        };
        "gracefulRestart" = mkOption {
          description = "GracefulRestart defines graceful restart parameters which are negotiated\nwith this peer.\n\nIf not specified, the graceful restart capability is disabled.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecGracefulRestart"));
        };
        "timers" = mkOption {
          description = "Timers defines the BGP timers for the peer.\n\nIf not specified, the default timers are used.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecTimers"));
        };
        "transport" = mkOption {
          description = "Transport defines the BGP transport parameters for the peer.\n\nIf not specified, the default transport parameters are used.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecTransport"));
        };
      };

      config = {
        "authSecretRef" = mkOverride 1002 null;
        "ebgpMultihop" = mkOverride 1002 null;
        "families" = mkOverride 1002 null;
        "gracefulRestart" = mkOverride 1002 null;
        "timers" = mkOverride 1002 null;
        "transport" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigSpecFamilies" = {

      options = {
        "advertisements" = mkOption {
          description = "Advertisements selects group of BGP Advertisement(s) to advertise for this family.\n\nIf not specified, no advertisements are sent for this family.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecFamiliesAdvertisements"));
        };
        "afi" = mkOption {
          description = "Afi is the Address Family Identifier (AFI) of the family.";
          type = types.str;
        };
        "safi" = mkOption {
          description = "Safi is the Subsequent Address Family Identifier (SAFI) of the family.";
          type = types.str;
        };
      };

      config = {
        "advertisements" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigSpecFamiliesAdvertisements" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumBGPPeerConfigSpecFamiliesAdvertisementsMatchExpressions"
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
    "cilium.io.v2.CiliumBGPPeerConfigSpecFamiliesAdvertisementsMatchExpressions" = {

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
    "cilium.io.v2.CiliumBGPPeerConfigSpecGracefulRestart" = {

      options = {
        "enabled" = mkOption {
          description = "Enabled flag, when set enables graceful restart capability.";
          type = types.bool;
        };
        "restartTimeSeconds" = mkOption {
          description = "RestartTimeSeconds is the estimated time it will take for the BGP\nsession to be re-established with peer after a restart.\nAfter this period, peer will remove stale routes. This is\ndescribed RFC 4724 section 4.2.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "restartTimeSeconds" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigSpecTimers" = {

      options = {
        "connectRetryTimeSeconds" = mkOption {
          description = "ConnectRetryTimeSeconds defines the initial value for the BGP ConnectRetryTimer (RFC 4271, Section 8).\n\nIf not specified, defaults to 120 seconds.";
          type = (types.nullOr types.int);
        };
        "holdTimeSeconds" = mkOption {
          description = "HoldTimeSeconds defines the initial value for the BGP HoldTimer (RFC 4271, Section 4.2).\nUpdating this value will cause a session reset.\n\nIf not specified, defaults to 90 seconds.";
          type = (types.nullOr types.int);
        };
        "keepAliveTimeSeconds" = mkOption {
          description = "KeepaliveTimeSeconds defines the initial value for the BGP KeepaliveTimer (RFC 4271, Section 8).\nIt can not be larger than HoldTimeSeconds. Updating this value will cause a session reset.\n\nIf not specified, defaults to 30 seconds.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "connectRetryTimeSeconds" = mkOverride 1002 null;
        "holdTimeSeconds" = mkOverride 1002 null;
        "keepAliveTimeSeconds" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigSpecTransport" = {

      options = {
        "peerPort" = mkOption {
          description = "PeerPort is the peer port to be used for the BGP session.\n\nIf not specified, defaults to TCP port 179.";
          type = (types.nullOr types.int);
        };
        "sourceInterface" = mkOption {
          description = "SourceInterface is the name of a local interface, which IP address will be used\nas the source IP address for the BGP session. The interface must not have more than one\nnon-loopback, non-multicast and non-link-local-IPv6 address per address family.\n\nIf not specified, or if the provided interface is not found or missing a usable IP address,\nthe source IP address will be auto-detected based on the egress interface.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "peerPort" = mkOverride 1002 null;
        "sourceInterface" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigStatus" = {

      options = {
        "conditions" = mkOption {
          description = "The current conditions of the CiliumBGPPeerConfig";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumBGPPeerConfigStatusConditions"))
          );
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumBGPPeerConfigStatusConditions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicy" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is the desired Cilium specific rule specification.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpec"));
        };
        "specs" = mkOption {
          description = "Specs is a list of desired Cilium specific rule specification.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecs"))
          );
        };
        "status" = mkOption {
          description = "Status is the status of the Cilium policy rule.\n\nThe reason this field exists in this structure is due a bug in the k8s\ncode-generator that doesn't create a `UpdateStatus` method because the\nfield does not exist in the structure.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicyStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "specs" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpec" = {

      options = {
        "description" = mkOption {
          description = "Description is a free form string, it can be used by the creator of\nthe rule to store human readable explanation of the purpose of this\nrule. Rules cannot be identified by comment.";
          type = (types.nullOr types.str);
        };
        "egress" = mkOption {
          description = "Egress is a list of EgressRule which are enforced at egress.\nIf omitted or empty, this rule does not apply at egress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgress"))
          );
        };
        "egressDeny" = mkOption {
          description = "EgressDeny is a list of EgressDenyRule which are enforced at egress.\nAny rule inserted here will be denied regardless of the allowed egress\nrules in the 'egress' field.\nIf omitted or empty, this rule does not apply at egress.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDeny")
            )
          );
        };
        "enableDefaultDeny" = mkOption {
          description = "EnableDefaultDeny determines whether this policy configures the\nsubject endpoint(s) to have a default deny mode. If enabled,\nthis causes all traffic not explicitly allowed by a network policy\nto be dropped.\n\nIf not specified, the default is true for each traffic direction\nthat has rules, and false otherwise. For example, if a policy\nonly has Ingress or IngressDeny rules, then the default for\ningress is true and egress is false.\n\nIf multiple policies apply to an endpoint, that endpoint's default deny\nwill be enabled if any policy requests it.\n\nThis is useful for creating broad-based network policies that will not\ncause endpoints to enter default-deny mode.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEnableDefaultDeny")
          );
        };
        "endpointSelector" = mkOption {
          description = "EndpointSelector selects all endpoints which should be subject to\nthis rule. EndpointSelector and NodeSelector cannot be both empty and\nare mutually exclusive.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEndpointSelector")
          );
        };
        "ingress" = mkOption {
          description = "Ingress is a list of IngressRule which are enforced at ingress.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngress"))
          );
        };
        "ingressDeny" = mkOption {
          description = "IngressDeny is a list of IngressDenyRule which are enforced at ingress.\nAny rule inserted here will be denied regardless of the allowed ingress\nrules in the 'ingress' field.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDeny")
            )
          );
        };
        "labels" = mkOption {
          description = "Labels is a list of optional strings which can be used to\nre-identify the rule or to store metadata. It is possible to lookup\nor delete strings based on labels. Labels are not required to be\nunique, multiple rules can have overlapping or identical labels.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecLabels"))
          );
        };
        "log" = mkOption {
          description = "Log specifies custom policy-specific Hubble logging configuration.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecLog"));
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects all nodes which should be subject to this rule.\nEndpointSelector and NodeSelector cannot be both empty and are mutually\nexclusive. Can only be used in CiliumClusterwideNetworkPolicies.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecNodeSelector"));
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "egress" = mkOverride 1002 null;
        "egressDeny" = mkOverride 1002 null;
        "enableDefaultDeny" = mkOverride 1002 null;
        "endpointSelector" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "ingressDeny" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "log" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressAuthentication")
          );
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressIcmps")
            )
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSet")
            )
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toFQDNs" = mkOption {
          description = "ToFQDN allows whitelisting DNS names in place of IPs. The IPs that result\nfrom DNS resolution of `ToFQDN.MatchName`s are added to the same\nEgressRule object as ToCIDRSet entries, and behave accordingly. Any L4 and\nL7 rules within this EgressRule will also apply to these IPs.\nThe DNS -> IP mapping is re-resolved periodically from within the\ncilium-agent, and the IPs in the DNS response are effected in the policy\nfor selected pods as-is (i.e. the list of IPs is not modified in any way).\nNote: An explicit rule to allow for DNS traffic is needed for the pods, as\nToFQDN counts as an egress rule and will enforce egress policy when\nPolicyEnforcment=default.\nNote: If the resolved IPs are IPs within the kubernetes cluster, the\nToFQDN rule will not apply to that IP.\nNote: ToFQDN cannot occur in the same policy as other To* rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToFQDNs")
            )
          );
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToGroups")
            )
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToNodes")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nconnect to.\n\nExample:\nAny endpoint with the label \"role=frontend\" is allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPorts")
            )
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServices")
            )
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toFQDNs" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDeny" = {

      options = {
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is not allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyIcmps")
            )
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSet")
            )
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToGroups")
            )
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToNodes")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to connect\nto.\n\nExample:\nAny endpoint with the label \"role=frontend\" is not allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToPorts")
            )
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServices")
            )
          );
        };
      };

      config = {
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sService"
            )
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToFQDNs" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsListener")
          );
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsOriginatingTLS"
            )
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsPorts")
            )
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRules")
          );
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsTerminatingTLS"
            )
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsListenerEnvoyConfig"
          );
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsOriginatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsTerminatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sService"
            )
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEgressToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEnableDefaultDeny" = {

      options = {
        "egress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto egress traffic.";
          type = (types.nullOr types.bool);
        };
        "ingress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto ingress traffic.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "egress" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEndpointSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEndpointSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecEndpointSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressAuthentication")
          );
        };
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromNodes")
            )
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressIcmps")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPorts")
            )
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDeny" = {

      options = {
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromNodes")
            )
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyIcmps")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyToPorts")
            )
          );
        };
      };

      config = {
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsListener")
          );
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsOriginatingTLS"
            )
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsPorts")
            )
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRules")
          );
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsTerminatingTLS"
            )
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsListenerEnvoyConfig"
          );
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsOriginatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsTerminatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecIngressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecLabels" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "source" = mkOption {
          description = "Source can be one of the above values (e.g.: LabelSourceContainer).";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "source" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecLog" = {

      options = {
        "value" = mkOption {
          description = "Value is a free-form string that is included in Hubble flows\nthat match this policy. The string is limited to 32 printable characters.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecNodeSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecs" = {

      options = {
        "description" = mkOption {
          description = "Description is a free form string, it can be used by the creator of\nthe rule to store human readable explanation of the purpose of this\nrule. Rules cannot be identified by comment.";
          type = (types.nullOr types.str);
        };
        "egress" = mkOption {
          description = "Egress is a list of EgressRule which are enforced at egress.\nIf omitted or empty, this rule does not apply at egress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgress"))
          );
        };
        "egressDeny" = mkOption {
          description = "EgressDeny is a list of EgressDenyRule which are enforced at egress.\nAny rule inserted here will be denied regardless of the allowed egress\nrules in the 'egress' field.\nIf omitted or empty, this rule does not apply at egress.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDeny")
            )
          );
        };
        "enableDefaultDeny" = mkOption {
          description = "EnableDefaultDeny determines whether this policy configures the\nsubject endpoint(s) to have a default deny mode. If enabled,\nthis causes all traffic not explicitly allowed by a network policy\nto be dropped.\n\nIf not specified, the default is true for each traffic direction\nthat has rules, and false otherwise. For example, if a policy\nonly has Ingress or IngressDeny rules, then the default for\ningress is true and egress is false.\n\nIf multiple policies apply to an endpoint, that endpoint's default deny\nwill be enabled if any policy requests it.\n\nThis is useful for creating broad-based network policies that will not\ncause endpoints to enter default-deny mode.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEnableDefaultDeny")
          );
        };
        "endpointSelector" = mkOption {
          description = "EndpointSelector selects all endpoints which should be subject to\nthis rule. EndpointSelector and NodeSelector cannot be both empty and\nare mutually exclusive.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEndpointSelector")
          );
        };
        "ingress" = mkOption {
          description = "Ingress is a list of IngressRule which are enforced at ingress.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngress"))
          );
        };
        "ingressDeny" = mkOption {
          description = "IngressDeny is a list of IngressDenyRule which are enforced at ingress.\nAny rule inserted here will be denied regardless of the allowed ingress\nrules in the 'ingress' field.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDeny")
            )
          );
        };
        "labels" = mkOption {
          description = "Labels is a list of optional strings which can be used to\nre-identify the rule or to store metadata. It is possible to lookup\nor delete strings based on labels. Labels are not required to be\nunique, multiple rules can have overlapping or identical labels.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsLabels"))
          );
        };
        "log" = mkOption {
          description = "Log specifies custom policy-specific Hubble logging configuration.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsLog"));
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects all nodes which should be subject to this rule.\nEndpointSelector and NodeSelector cannot be both empty and are mutually\nexclusive. Can only be used in CiliumClusterwideNetworkPolicies.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsNodeSelector"));
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "egress" = mkOverride 1002 null;
        "egressDeny" = mkOverride 1002 null;
        "enableDefaultDeny" = mkOverride 1002 null;
        "endpointSelector" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "ingressDeny" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "log" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressAuthentication")
          );
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressIcmps")
            )
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSet")
            )
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toFQDNs" = mkOption {
          description = "ToFQDN allows whitelisting DNS names in place of IPs. The IPs that result\nfrom DNS resolution of `ToFQDN.MatchName`s are added to the same\nEgressRule object as ToCIDRSet entries, and behave accordingly. Any L4 and\nL7 rules within this EgressRule will also apply to these IPs.\nThe DNS -> IP mapping is re-resolved periodically from within the\ncilium-agent, and the IPs in the DNS response are effected in the policy\nfor selected pods as-is (i.e. the list of IPs is not modified in any way).\nNote: An explicit rule to allow for DNS traffic is needed for the pods, as\nToFQDN counts as an egress rule and will enforce egress policy when\nPolicyEnforcment=default.\nNote: If the resolved IPs are IPs within the kubernetes cluster, the\nToFQDN rule will not apply to that IP.\nNote: ToFQDN cannot occur in the same policy as other To* rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToFQDNs")
            )
          );
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToGroups")
            )
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToNodes")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nconnect to.\n\nExample:\nAny endpoint with the label \"role=frontend\" is allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPorts")
            )
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServices")
            )
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toFQDNs" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDeny" = {

      options = {
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is not allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyIcmps")
            )
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSet")
            )
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToGroups")
            )
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToNodes")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to connect\nto.\n\nExample:\nAny endpoint with the label \"role=frontend\" is not allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToPorts")
            )
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServices")
            )
          );
        };
      };

      config = {
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sService"
            )
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToFQDNs" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsListener")
          );
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsOriginatingTLS"
            )
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsPorts")
            )
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRules")
          );
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsTerminatingTLS"
            )
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsListenerEnvoyConfig"
          );
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsOriginatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsTerminatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sService"
            )
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEnableDefaultDeny" = {

      options = {
        "egress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto egress traffic.";
          type = (types.nullOr types.bool);
        };
        "ingress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto ingress traffic.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "egress" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEndpointSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEndpointSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsEndpointSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressAuthentication")
          );
        };
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromNodes")
            )
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressIcmps")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPorts")
            )
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDeny" = {

      options = {
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromEndpoints"
              )
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromNodes")
            )
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyIcmps")
            )
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyToPorts")
            )
          );
        };
      };

      config = {
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromGroupsAws"
            )
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromGroupsAws")
          );
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsListener")
          );
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsOriginatingTLS"
            )
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsPorts")
            )
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRules")
          );
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsTerminatingTLS"
            )
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsListenerEnvoyConfig"
          );
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsOriginatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesKafka"
              )
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (
            submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsTerminatingTLSSecret"
          );
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsIngressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsLabels" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "source" = mkOption {
          description = "Source can be one of the above values (e.g.: LabelSourceContainer).";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "source" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsLog" = {

      options = {
        "value" = mkOption {
          description = "Value is a free-form string that is included in Hubble flows\nthat match this policy. The string is limited to 32 printable characters.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsNodeSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumClusterwideNetworkPolicySpecsNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumClusterwideNetworkPolicyStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumClusterwideNetworkPolicyStatusConditions")
            )
          );
        };
        "derivativePolicies" = mkOption {
          description = "DerivativePolicies is the status of all policies derived from the Cilium\npolicy";
          type = (types.nullOr (types.attrsOf types.attrs));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "derivativePolicies" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumClusterwideNetworkPolicyStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "The last time the condition transitioned from one status to another.";
          type = (types.nullOr types.str);
        };
        "message" = mkOption {
          description = "A human readable message indicating details about the transition.";
          type = (types.nullOr types.str);
        };
        "reason" = mkOption {
          description = "The reason for the condition's last transition.";
          type = (types.nullOr types.str);
        };
        "status" = mkOption {
          description = "The status of the condition, one of True, False, or Unknown";
          type = types.str;
        };
        "type" = mkOption {
          description = "The type of the policy condition";
          type = types.str;
        };
      };

      config = {
        "lastTransitionTime" = mkOverride 1002 null;
        "message" = mkOverride 1002 null;
        "reason" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumLoadBalancerIPPool" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is a human readable description for a BGP load balancer\nip pool.";
          type = (submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolSpec");
        };
        "status" = mkOption {
          description = "Status is the status of the IP Pool.\n\nIt might be possible for users to define overlapping IP Pools, we can't validate or enforce non-overlapping pools\nduring object creation. The Cilium operator will do this validation and update the status to reflect the ability\nto allocate IPs from this pool.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumLoadBalancerIPPoolSpec" = {

      options = {
        "allowFirstLastIPs" = mkOption {
          description = "AllowFirstLastIPs, if set to `Yes` or undefined means that the first and last IPs of each CIDR will be allocatable.\nIf `No`, these IPs will be reserved. This field is ignored for /{31,32} and /{127,128} CIDRs since\nreserving the first and last IPs would make the CIDRs unusable.";
          type = (types.nullOr types.str);
        };
        "blocks" = mkOption {
          description = "Blocks is a list of CIDRs comprising this IP Pool";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolSpecBlocks"))
          );
        };
        "disabled" = mkOption {
          description = "Disabled, if set to true means that no new IPs will be allocated from this pool.\nExisting allocations will not be removed from services.";
          type = (types.nullOr types.bool);
        };
        "serviceSelector" = mkOption {
          description = "ServiceSelector selects a set of services which are eligible to receive IPs from this";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolSpecServiceSelector"));
        };
      };

      config = {
        "allowFirstLastIPs" = mkOverride 1002 null;
        "blocks" = mkOverride 1002 null;
        "disabled" = mkOverride 1002 null;
        "serviceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumLoadBalancerIPPoolSpecBlocks" = {

      options = {
        "cidr" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "start" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "stop" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "start" = mkOverride 1002 null;
        "stop" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumLoadBalancerIPPoolSpecServiceSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolSpecServiceSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumLoadBalancerIPPoolSpecServiceSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumLoadBalancerIPPoolStatus" = {

      options = {
        "conditions" = mkOption {
          description = "Current service state";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumLoadBalancerIPPoolStatusConditions"))
          );
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumLoadBalancerIPPoolStatusConditions" = {

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
    "cilium.io.v2.CiliumNetworkPolicy" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is the desired Cilium specific rule specification.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpec"));
        };
        "specs" = mkOption {
          description = "Specs is a list of desired Cilium specific rule specification.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecs")));
        };
        "status" = mkOption {
          description = "Status is the status of the Cilium policy rule";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicyStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "specs" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpec" = {

      options = {
        "description" = mkOption {
          description = "Description is a free form string, it can be used by the creator of\nthe rule to store human readable explanation of the purpose of this\nrule. Rules cannot be identified by comment.";
          type = (types.nullOr types.str);
        };
        "egress" = mkOption {
          description = "Egress is a list of EgressRule which are enforced at egress.\nIf omitted or empty, this rule does not apply at egress.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgress")));
        };
        "egressDeny" = mkOption {
          description = "EgressDeny is a list of EgressDenyRule which are enforced at egress.\nAny rule inserted here will be denied regardless of the allowed egress\nrules in the 'egress' field.\nIf omitted or empty, this rule does not apply at egress.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDeny")));
        };
        "enableDefaultDeny" = mkOption {
          description = "EnableDefaultDeny determines whether this policy configures the\nsubject endpoint(s) to have a default deny mode. If enabled,\nthis causes all traffic not explicitly allowed by a network policy\nto be dropped.\n\nIf not specified, the default is true for each traffic direction\nthat has rules, and false otherwise. For example, if a policy\nonly has Ingress or IngressDeny rules, then the default for\ningress is true and egress is false.\n\nIf multiple policies apply to an endpoint, that endpoint's default deny\nwill be enabled if any policy requests it.\n\nThis is useful for creating broad-based network policies that will not\ncause endpoints to enter default-deny mode.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEnableDefaultDeny"));
        };
        "endpointSelector" = mkOption {
          description = "EndpointSelector selects all endpoints which should be subject to\nthis rule. EndpointSelector and NodeSelector cannot be both empty and\nare mutually exclusive.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEndpointSelector"));
        };
        "ingress" = mkOption {
          description = "Ingress is a list of IngressRule which are enforced at ingress.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngress")));
        };
        "ingressDeny" = mkOption {
          description = "IngressDeny is a list of IngressDenyRule which are enforced at ingress.\nAny rule inserted here will be denied regardless of the allowed ingress\nrules in the 'ingress' field.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDeny"))
          );
        };
        "labels" = mkOption {
          description = "Labels is a list of optional strings which can be used to\nre-identify the rule or to store metadata. It is possible to lookup\nor delete strings based on labels. Labels are not required to be\nunique, multiple rules can have overlapping or identical labels.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecLabels")));
        };
        "log" = mkOption {
          description = "Log specifies custom policy-specific Hubble logging configuration.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecLog"));
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects all nodes which should be subject to this rule.\nEndpointSelector and NodeSelector cannot be both empty and are mutually\nexclusive. Can only be used in CiliumClusterwideNetworkPolicies.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecNodeSelector"));
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "egress" = mkOverride 1002 null;
        "egressDeny" = mkOverride 1002 null;
        "enableDefaultDeny" = mkOverride 1002 null;
        "endpointSelector" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "ingressDeny" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "log" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressAuthentication"));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressIcmps"))
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSet"))
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToEndpoints"))
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toFQDNs" = mkOption {
          description = "ToFQDN allows whitelisting DNS names in place of IPs. The IPs that result\nfrom DNS resolution of `ToFQDN.MatchName`s are added to the same\nEgressRule object as ToCIDRSet entries, and behave accordingly. Any L4 and\nL7 rules within this EgressRule will also apply to these IPs.\nThe DNS -> IP mapping is re-resolved periodically from within the\ncilium-agent, and the IPs in the DNS response are effected in the policy\nfor selected pods as-is (i.e. the list of IPs is not modified in any way).\nNote: An explicit rule to allow for DNS traffic is needed for the pods, as\nToFQDN counts as an egress rule and will enforce egress policy when\nPolicyEnforcment=default.\nNote: If the resolved IPs are IPs within the kubernetes cluster, the\nToFQDN rule will not apply to that IP.\nNote: ToFQDN cannot occur in the same policy as other To* rules.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToFQDNs"))
          );
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToGroups"))
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToNodes"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nconnect to.\n\nExample:\nAny endpoint with the label \"role=frontend\" is allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPorts"))
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToServices"))
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toFQDNs" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDeny" = {

      options = {
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is not allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyIcmps"))
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSet"))
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToGroups"))
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToNodes"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to connect\nto.\n\nExample:\nAny endpoint with the label \"role=frontend\" is not allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToPorts"))
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServices"))
          );
        };
      };

      config = {
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sService")
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressIcmpsFields"))
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSetCidrGroupSelector")
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToEndpointsMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToFQDNs" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsListener"));
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsOriginatingTLS")
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsPorts"))
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRules"));
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsTerminatingTLS")
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsListenerEnvoyConfig");
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsOriginatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsTerminatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sService")
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelector")
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecEgressToServicesK8sServiceSelectorSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecEnableDefaultDeny" = {

      options = {
        "egress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto egress traffic.";
          type = (types.nullOr types.bool);
        };
        "ingress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto ingress traffic.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "egress" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecEndpointSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecEndpointSelectorMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecEndpointSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressAuthentication"));
        };
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSet"))
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromEndpoints"))
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromGroups"))
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromNodes"))
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressIcmps"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPorts"))
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDeny" = {

      options = {
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromNodes"))
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyIcmps"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyToPorts"))
          );
        };
      };

      config = {
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSetCidrGroupSelector")
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressFromNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecIngressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressIcmpsFields"))
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsListener"));
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsOriginatingTLS")
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsPorts"))
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRules"));
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsTerminatingTLS")
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsListenerEnvoyConfig");
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsOriginatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsTerminatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecIngressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecLabels" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "source" = mkOption {
          description = "Source can be one of the above values (e.g.: LabelSourceContainer).";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "source" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecLog" = {

      options = {
        "value" = mkOption {
          description = "Value is a free-form string that is included in Hubble flows\nthat match this policy. The string is limited to 32 printable characters.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecNodeSelectorMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecs" = {

      options = {
        "description" = mkOption {
          description = "Description is a free form string, it can be used by the creator of\nthe rule to store human readable explanation of the purpose of this\nrule. Rules cannot be identified by comment.";
          type = (types.nullOr types.str);
        };
        "egress" = mkOption {
          description = "Egress is a list of EgressRule which are enforced at egress.\nIf omitted or empty, this rule does not apply at egress.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgress")));
        };
        "egressDeny" = mkOption {
          description = "EgressDeny is a list of EgressDenyRule which are enforced at egress.\nAny rule inserted here will be denied regardless of the allowed egress\nrules in the 'egress' field.\nIf omitted or empty, this rule does not apply at egress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDeny"))
          );
        };
        "enableDefaultDeny" = mkOption {
          description = "EnableDefaultDeny determines whether this policy configures the\nsubject endpoint(s) to have a default deny mode. If enabled,\nthis causes all traffic not explicitly allowed by a network policy\nto be dropped.\n\nIf not specified, the default is true for each traffic direction\nthat has rules, and false otherwise. For example, if a policy\nonly has Ingress or IngressDeny rules, then the default for\ningress is true and egress is false.\n\nIf multiple policies apply to an endpoint, that endpoint's default deny\nwill be enabled if any policy requests it.\n\nThis is useful for creating broad-based network policies that will not\ncause endpoints to enter default-deny mode.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEnableDefaultDeny"));
        };
        "endpointSelector" = mkOption {
          description = "EndpointSelector selects all endpoints which should be subject to\nthis rule. EndpointSelector and NodeSelector cannot be both empty and\nare mutually exclusive.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEndpointSelector"));
        };
        "ingress" = mkOption {
          description = "Ingress is a list of IngressRule which are enforced at ingress.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngress")));
        };
        "ingressDeny" = mkOption {
          description = "IngressDeny is a list of IngressDenyRule which are enforced at ingress.\nAny rule inserted here will be denied regardless of the allowed ingress\nrules in the 'ingress' field.\nIf omitted or empty, this rule does not apply at ingress.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDeny"))
          );
        };
        "labels" = mkOption {
          description = "Labels is a list of optional strings which can be used to\nre-identify the rule or to store metadata. It is possible to lookup\nor delete strings based on labels. Labels are not required to be\nunique, multiple rules can have overlapping or identical labels.";
          type = (types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsLabels")));
        };
        "log" = mkOption {
          description = "Log specifies custom policy-specific Hubble logging configuration.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsLog"));
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects all nodes which should be subject to this rule.\nEndpointSelector and NodeSelector cannot be both empty and are mutually\nexclusive. Can only be used in CiliumClusterwideNetworkPolicies.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsNodeSelector"));
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "egress" = mkOverride 1002 null;
        "egressDeny" = mkOverride 1002 null;
        "enableDefaultDeny" = mkOverride 1002 null;
        "endpointSelector" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "ingressDeny" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "log" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressAuthentication"));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressIcmps"))
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSet"))
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToEndpoints"))
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toFQDNs" = mkOption {
          description = "ToFQDN allows whitelisting DNS names in place of IPs. The IPs that result\nfrom DNS resolution of `ToFQDN.MatchName`s are added to the same\nEgressRule object as ToCIDRSet entries, and behave accordingly. Any L4 and\nL7 rules within this EgressRule will also apply to these IPs.\nThe DNS -> IP mapping is re-resolved periodically from within the\ncilium-agent, and the IPs in the DNS response are effected in the policy\nfor selected pods as-is (i.e. the list of IPs is not modified in any way).\nNote: An explicit rule to allow for DNS traffic is needed for the pods, as\nToFQDN counts as an egress rule and will enforce egress policy when\nPolicyEnforcment=default.\nNote: If the resolved IPs are IPs within the kubernetes cluster, the\nToFQDN rule will not apply to that IP.\nNote: ToFQDN cannot occur in the same policy as other To* rules.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToFQDNs"))
          );
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToGroups"))
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToNodes"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nconnect to.\n\nExample:\nAny endpoint with the label \"role=frontend\" is allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPorts"))
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServices"))
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toFQDNs" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDeny" = {

      options = {
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to connect to.\n\nExample:\nAny endpoint with the label \"app=httpd\" is not allowed to initiate\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyIcmps"))
          );
        };
        "toCIDR" = mkOption {
          description = "ToCIDR is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections. Only connections destined for\noutside of the cluster and not targeting the host will be subject\nto CIDR rules.  This will match on the destination IP address of\noutgoing connections. Adding a prefix into ToCIDR or into ToCIDRSet\nwith no ExcludeCIDRs is equivalent. Overlaps are allowed between\nToCIDR and ToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24";
          type = (types.nullOr (types.listOf types.str));
        };
        "toCIDRSet" = mkOption {
          description = "ToCIDRSet is a list of IP blocks which the endpoint subject to the rule\nis allowed to initiate connections to in addition to connections\nwhich are allowed via ToEndpoints, along with a list of subnets contained\nwithin their corresponding IP block to which traffic should not be\nallowed. This will match on the destination IP address of outgoing\nconnections. Adding a prefix into ToCIDR or into ToCIDRSet with no\nExcludeCIDRs is equivalent. Overlaps are allowed between ToCIDR and\nToCIDRSet.\n\nExample:\nAny endpoint with the label \"app=database-proxy\" is allowed to\ninitiate connections to 10.2.3.0/24 except from IPs in subnet 10.2.3.0/28.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSet"))
          );
        };
        "toEndpoints" = mkOption {
          description = "ToEndpoints is a list of endpoints identified by an EndpointSelector to\nwhich the endpoints subject to the rule are allowed to communicate.\n\nExample:\nAny endpoint with the label \"role=frontend\" can communicate with any\nendpoint carrying the label \"role=backend\".\n\nNote that while an empty non-nil ToEndpoints does not select anything,\nnil ToEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToEndpoints")
            )
          );
        };
        "toEntities" = mkOption {
          description = "ToEntities is a list of special entities to which the endpoint subject\nto the rule is allowed to initiate connections. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toGroups" = mkOption {
          description = "ToGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\ntoGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToGroups"))
          );
        };
        "toNodes" = mkOption {
          description = "ToNodes is a list of nodes identified by an\nEndpointSelector to which endpoints subject to the rule is allowed to communicate.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToNodes"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to connect\nto.\n\nExample:\nAny endpoint with the label \"role=frontend\" is not allowed to initiate\nconnections to destination port 8080/tcp";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToPorts"))
          );
        };
        "toRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "toServices" = mkOption {
          description = "ToServices is a list of services to which the endpoint subject\nto the rule is allowed to initiate connections.\nCurrently Cilium only supports toServices for K8s services.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServices")
            )
          );
        };
      };

      config = {
        "icmps" = mkOverride 1002 null;
        "toCIDR" = mkOverride 1002 null;
        "toCIDRSet" = mkOverride 1002 null;
        "toEndpoints" = mkOverride 1002 null;
        "toEntities" = mkOverride 1002 null;
        "toGroups" = mkOverride 1002 null;
        "toNodes" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
        "toRequires" = mkOverride 1002 null;
        "toServices" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sService")
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelector"
            )
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressDenyToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressIcmpsFields"))
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSetCidrGroupSelector")
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToEndpointsMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToFQDNs" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsListener"));
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsOriginatingTLS")
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsPorts"))
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRules"));
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsTerminatingTLS")
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsListenerEnvoyConfig");
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsOriginatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsTerminatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServices" = {

      options = {
        "k8sService" = mkOption {
          description = "K8sService selects service by name and namespace pair";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sService")
          );
        };
        "k8sServiceSelector" = mkOption {
          description = "K8sServiceSelector selects services by k8s labels and namespace";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelector")
          );
        };
      };

      config = {
        "k8sService" = mkOverride 1002 null;
        "k8sServiceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sService" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "serviceName" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "serviceName" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelector" = {

      options = {
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "selector" = mkOption {
          description = "ServiceSelector is a label selector for k8s services";
          type = (
            submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEgressToServicesK8sServiceSelectorSelectorMatchExpressions" =
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEnableDefaultDeny" = {

      options = {
        "egress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto egress traffic.";
          type = (types.nullOr types.bool);
        };
        "ingress" = mkOption {
          description = "Whether or not the endpoint should have a default-deny rule applied\nto ingress traffic.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "egress" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsEndpointSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsEndpointSelectorMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsEndpointSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngress" = {

      options = {
        "authentication" = mkOption {
          description = "Authentication is the required authentication type for the allowed traffic, if any.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressAuthentication"));
        };
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSet"))
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromGroups"))
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromNodes"))
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressIcmps"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can only accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPorts"))
          );
        };
      };

      config = {
        "authentication" = mkOverride 1002 null;
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressAuthentication" = {

      options = {
        "mode" = mkOption {
          description = "Mode is the required authentication mode for the allowed traffic, if any.";
          type = types.str;
        };
      };

      config = { };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDeny" = {

      options = {
        "fromCIDR" = mkOption {
          description = "FromCIDR is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from. Only connections which\ndo *not* originate from the cluster or from the local host are subject\nto CIDR rules. In order to allow in-cluster connectivity, use the\nFromEndpoints field.  This will match on the source IP address of\nincoming connections. Adding  a prefix into FromCIDR or into\nFromCIDRSet with no ExcludeCIDRs is  equivalent.  Overlaps are\nallowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.3.9.1";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromCIDRSet" = mkOption {
          description = "FromCIDRSet is a list of IP blocks which the endpoint subject to the\nrule is allowed to receive connections from in addition to FromEndpoints,\nalong with a list of subnets contained within their corresponding IP block\nfrom which traffic should not be allowed.\nThis will match on the source IP address of incoming connections. Adding\na prefix into FromCIDR or into FromCIDRSet with no ExcludeCIDRs is\nequivalent. Overlaps are allowed between FromCIDR and FromCIDRSet.\n\nExample:\nAny endpoint with the label \"app=my-legacy-pet\" is allowed to receive\nconnections from 10.0.0.0/8 except from IPs in subnet 10.96.0.0/12.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSet")
            )
          );
        };
        "fromEndpoints" = mkOption {
          description = "FromEndpoints is a list of endpoints identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.\n\nExample:\nAny endpoint with the label \"role=backend\" can be consumed by any\nendpoint carrying the label \"role=frontend\".\n\nNote that while an empty non-nil FromEndpoints does not select anything,\nnil FromEndpoints is implicitly treated as a wildcard selector if ToPorts\nare also specified.\nTo select everything, use one EndpointSelector without any match requirements.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromEndpoints")
            )
          );
        };
        "fromEntities" = mkOption {
          description = "FromEntities is a list of special entities which the endpoint subject\nto the rule is allowed to receive connections from. Supported entities are\n`world`, `cluster`, `host`, `remote-node`, `kube-apiserver`, `ingress`, `init`,\n`health`, `unmanaged`, `none` and `all`.";
          type = (types.nullOr (types.listOf types.str));
        };
        "fromGroups" = mkOption {
          description = "FromGroups is a directive that allows the integration with multiple outside\nproviders. Currently, only AWS is supported, and the rule can select by\nmultiple sub directives:\n\nExample:\nFromGroups:\n- aws:\n    securityGroupsIds:\n    - 'sg-XXXXXXXXXXXXX'";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromGroups")
            )
          );
        };
        "fromNodes" = mkOption {
          description = "FromNodes is a list of nodes identified by an\nEndpointSelector which are allowed to communicate with the endpoint\nsubject to the rule.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromNodes")
            )
          );
        };
        "fromRequires" = mkOption {
          description = "Deprecated.";
          type = (types.nullOr (types.listOf types.str));
        };
        "icmps" = mkOption {
          description = "ICMPs is a list of ICMP rule identified by type number\nwhich the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\ntype 8 ICMP connections.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyIcmps"))
          );
        };
        "toPorts" = mkOption {
          description = "ToPorts is a list of destination ports identified by port number and\nprotocol which the endpoint subject to the rule is not allowed to\nreceive connections on.\n\nExample:\nAny endpoint with the label \"app=httpd\" can not accept incoming\nconnections on port 80/tcp.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyToPorts"))
          );
        };
      };

      config = {
        "fromCIDR" = mkOverride 1002 null;
        "fromCIDRSet" = mkOverride 1002 null;
        "fromEndpoints" = mkOverride 1002 null;
        "fromEntities" = mkOverride 1002 null;
        "fromGroups" = mkOverride 1002 null;
        "fromNodes" = mkOverride 1002 null;
        "fromRequires" = mkOverride 1002 null;
        "icmps" = mkOverride 1002 null;
        "toPorts" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromNodesMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyIcmpsFields")
            )
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyToPorts" = {

      options = {
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyToPortsPorts")
            )
          );
        };
      };

      config = {
        "ports" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressDenyToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSet" = {

      options = {
        "cidr" = mkOption {
          description = "CIDR is a CIDR prefix / IP Block.";
          type = (types.nullOr types.str);
        };
        "cidrGroupRef" = mkOption {
          description = "CIDRGroupRef is a reference to a CiliumCIDRGroup object.\nA CiliumCIDRGroup contains a list of CIDRs that the endpoint, subject to\nthe rule, can (Ingress/Egress) or cannot (IngressDeny/EgressDeny) receive\nconnections from.";
          type = (types.nullOr types.str);
        };
        "cidrGroupSelector" = mkOption {
          description = "CIDRGroupSelector selects CiliumCIDRGroups by their labels,\nrather than by name.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelector"
            )
          );
        };
        "except" = mkOption {
          description = "ExceptCIDRs is a list of IP blocks which the endpoint subject to the rule\nis not allowed to initiate connections to. These CIDR prefixes should be\ncontained within Cidr, using ExceptCIDRs together with CIDRGroupRef is not\nsupported yet.\nThese exceptions are only applied to the Cidr in this CIDRRule, and do not\napply to any other CIDR prefixes in any other CIDRRules.";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "cidr" = mkOverride 1002 null;
        "cidrGroupRef" = mkOverride 1002 null;
        "cidrGroupSelector" = mkOverride 1002 null;
        "except" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelectorMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromCIDRSetCidrGroupSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromEndpoints" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromEndpointsMatchExpressions"
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromEndpointsMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromGroups" = {

      options = {
        "aws" = mkOption {
          description = "AWSGroup is an structure that can be used to whitelisting information from AWS integration";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromGroupsAws"));
        };
      };

      config = {
        "aws" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromGroupsAws" = {

      options = {
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "region" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "securityGroupsIds" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "securityGroupsNames" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "securityGroupsIds" = mkOverride 1002 null;
        "securityGroupsNames" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromNodes" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromNodesMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressFromNodesMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressIcmps" = {

      options = {
        "fields" = mkOption {
          description = "Fields is a list of ICMP fields.";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressIcmpsFields"))
          );
        };
      };

      config = {
        "fields" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressIcmpsFields" = {

      options = {
        "family" = mkOption {
          description = "Family is a IP address version.\nCurrently, we support `IPv4` and `IPv6`.\n`IPv4` is set as default.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a ICMP-type.\nIt should be an 8bit code (0-255), or it's CamelCase name (for example, \"EchoReply\").\nAllowed ICMP types are:\n    Ipv4: EchoReply | DestinationUnreachable | Redirect | Echo | EchoRequest |\n\t\t     RouterAdvertisement | RouterSelection | TimeExceeded | ParameterProblem |\n\t\t\t Timestamp | TimestampReply | Photuris | ExtendedEcho Request | ExtendedEcho Reply\n    Ipv6: DestinationUnreachable | PacketTooBig | TimeExceeded | ParameterProblem |\n\t\t\t EchoRequest | EchoReply | MulticastListenerQuery| MulticastListenerReport |\n\t\t\t MulticastListenerDone | RouterSolicitation | RouterAdvertisement | NeighborSolicitation |\n\t\t\t NeighborAdvertisement | RedirectMessage | RouterRenumbering | ICMPNodeInformationQuery |\n\t\t\t ICMPNodeInformationResponse | InverseNeighborDiscoverySolicitation | InverseNeighborDiscoveryAdvertisement |\n\t\t\t HomeAgentAddressDiscoveryRequest | HomeAgentAddressDiscoveryReply | MobilePrefixSolicitation |\n\t\t\t MobilePrefixAdvertisement | DuplicateAddressRequestCodeSuffix | DuplicateAddressConfirmationCodeSuffix |\n\t\t\t ExtendedEchoRequest | ExtendedEchoReply";
          type = (types.either types.int types.str);
        };
      };

      config = {
        "family" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPorts" = {

      options = {
        "listener" = mkOption {
          description = "listener specifies the name of a custom Envoy listener to which this traffic should be\nredirected to.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsListener"));
        };
        "originatingTLS" = mkOption {
          description = "OriginatingTLS is the TLS context for the connections originated by\nthe L7 proxy.  For egress policy this specifies the client-side TLS\nparameters for the upstream connection originating from the L7 proxy\nto the remote destination. For ingress policy this specifies the\nclient-side TLS parameters for the connection from the L7 proxy to\nthe local endpoint.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsOriginatingTLS")
          );
        };
        "ports" = mkOption {
          description = "Ports is a list of L4 port/protocol";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsPorts"))
          );
        };
        "rules" = mkOption {
          description = "Rules is a list of additional port level rules which must be met in\norder for the PortRule to allow the traffic. If omitted or empty,\nno layer 7 rules are enforced.";
          type = (types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRules"));
        };
        "serverNames" = mkOption {
          description = "ServerNames is a list of allowed TLS SNI values. If not empty, then\nTLS must be present and one of the provided SNIs must be indicated in the\nTLS handshake.";
          type = (types.nullOr (types.listOf types.str));
        };
        "terminatingTLS" = mkOption {
          description = "TerminatingTLS is the TLS context for the connection terminated by\nthe L7 proxy.  For egress policy this specifies the server-side TLS\nparameters to be applied on the connections originated from the local\nendpoint and terminated by the L7 proxy. For ingress policy this specifies\nthe server-side TLS parameters to be applied on the connections\noriginated from a remote source and terminated by the L7 proxy.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsTerminatingTLS")
          );
        };
      };

      config = {
        "listener" = mkOverride 1002 null;
        "originatingTLS" = mkOverride 1002 null;
        "ports" = mkOverride 1002 null;
        "rules" = mkOverride 1002 null;
        "serverNames" = mkOverride 1002 null;
        "terminatingTLS" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsListener" = {

      options = {
        "envoyConfig" = mkOption {
          description = "EnvoyConfig is a reference to the CEC or CCEC resource in which\nthe listener is defined.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsListenerEnvoyConfig");
        };
        "name" = mkOption {
          description = "Name is the name of the listener.";
          type = types.str;
        };
        "priority" = mkOption {
          description = "Priority for this Listener that is used when multiple rules would apply different\nlisteners to a policy map entry. Behavior of this is implementation dependent.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "priority" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsListenerEnvoyConfig" = {

      options = {
        "kind" = mkOption {
          description = "Kind is the resource type being referred to. Defaults to CiliumEnvoyConfig or\nCiliumClusterwideEnvoyConfig for CiliumNetworkPolicy and CiliumClusterwideNetworkPolicy,\nrespectively. The only case this is currently explicitly needed is when referring to a\nCiliumClusterwideEnvoyConfig from CiliumNetworkPolicy, as using a namespaced listener\nfrom a cluster scoped policy is not allowed.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name is the resource name of the CiliumEnvoyConfig or CiliumClusterwideEnvoyConfig where\nthe listener is defined in.";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsOriginatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsOriginatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsOriginatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsPorts" = {

      options = {
        "endPort" = mkOption {
          description = "EndPort can only be an L4 port number.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "Port can be an L4 port number, or a name in the form of \"http\"\nor \"http-8080\".";
          type = (types.nullOr types.str);
        };
        "protocol" = mkOption {
          description = "Protocol is the L4 protocol. If \"ANY\", omitted or empty, any protocols\nwith transport ports (TCP, UDP, SCTP) match.\n\nAccepted values: \"TCP\", \"UDP\", \"SCTP\", \"VRRP\", \"IGMP\", \"ANY\"\n\nMatching on ICMP is not supported.\n\nNamed port specified for a container may narrow this down, but may not\ncontradict this.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "protocol" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRules" = {

      options = {
        "dns" = mkOption {
          description = "DNS-specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesDns")
            )
          );
        };
        "http" = mkOption {
          description = "HTTP specific rules.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttp")
            )
          );
        };
        "kafka" = mkOption {
          description = "Kafka-specific rules.\nDeprecated: This beta feature is deprecated and will be removed in a future release.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesKafka")
            )
          );
        };
        "l7" = mkOption {
          description = "Key-value pair rules.";
          type = (types.nullOr (types.listOf types.attrs));
        };
        "l7proto" = mkOption {
          description = "Name of the L7 protocol for which the Key-value pair rules apply.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "dns" = mkOverride 1002 null;
        "http" = mkOverride 1002 null;
        "kafka" = mkOverride 1002 null;
        "l7" = mkOverride 1002 null;
        "l7proto" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesDns" = {

      options = {
        "matchName" = mkOption {
          description = "MatchName matches literal DNS names. A trailing \".\" is automatically added\nwhen missing.";
          type = (types.nullOr types.str);
        };
        "matchPattern" = mkOption {
          description = "MatchPattern allows using wildcards to match DNS names. All wildcards are\ncase insensitive. The wildcards are:\n- \"*\" matches 0 or more DNS valid characters, and may occur anywhere in\nthe pattern. As a special case a \"*\" as the leftmost character, without a\nfollowing \".\" matches all subdomains as well as the name to the right.\nA trailing \".\" is automatically added when missing.\n- \"**.\" is a special prefix which matches all multilevel subdomains in the prefix.\n\nExamples:\n1. `*.cilium.io` matches subdomains of cilium at that level\n  www.cilium.io and blog.cilium.io match, cilium.io and google.com do not\n2. `*cilium.io` matches cilium.io and all subdomains ends with \"cilium.io\"\n  except those containing \".\" separator, subcilium.io and sub-cilium.io match,\n  www.cilium.io and blog.cilium.io does not\n3. `sub*.cilium.io` matches subdomains of cilium where the subdomain component\n  begins with \"sub\". sub.cilium.io and subdomain.cilium.io match while www.cilium.io,\n  blog.cilium.io, cilium.io and google.com do not\n4. `**.cilium.io` matches all multilevel subdomains of cilium.io.\n  \"app.cilium.io\" and \"test.app.cilium.io\" match but not \"cilium.io\"";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "matchName" = mkOverride 1002 null;
        "matchPattern" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttp" = {

      options = {
        "headerMatches" = mkOption {
          description = "HeaderMatches is a list of HTTP headers which must be\npresent and match against the given values. Mismatch field can be used\nto specify what to do when there is no match.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatches"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "headers" = mkOption {
          description = "Headers is a list of HTTP headers which must be present in the\nrequest. If omitted or empty, requests are allowed regardless of\nheaders present.";
          type = (types.nullOr (types.listOf types.str));
        };
        "host" = mkOption {
          description = "Host is an extended POSIX regex matched against the host header of a\nrequest. Examples:\n\n- foo.bar.com will match the host fooXbar.com or foo-bar.com\n- foo\\.bar\\.com will only match the host foo.bar.com\n\nIf omitted or empty, the value of the host header is ignored.";
          type = (types.nullOr types.str);
        };
        "method" = mkOption {
          description = "Method is an extended POSIX regex matched against the method of a\nrequest, e.g. \"GET\", \"POST\", \"PUT\", \"PATCH\", \"DELETE\", ...\n\nIf omitted or empty, all methods are allowed.";
          type = (types.nullOr types.str);
        };
        "path" = mkOption {
          description = "Path is an extended POSIX regex matched against the path of a\nrequest. Currently it can contain characters disallowed from the\nconventional \"path\" part of a URL as defined by RFC 3986.\n\nIf omitted or empty, all paths are all allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "headerMatches" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatches" = {

      options = {
        "mismatch" = mkOption {
          description = "Mismatch identifies what to do in case there is no match. The default is\nto drop the request. Otherwise the overall rule is still considered as\nmatching, but the mismatches are logged in the access log.";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "Name identifies the header.";
          type = types.str;
        };
        "secret" = mkOption {
          description = "Secret refers to a secret that contains the value to be matched against.\nThe secret must only contain one entry. If the referred secret does not\nexist, and there is no \"Value\" specified, the match will fail.";
          type = (
            types.nullOr (
              submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatchesSecret"
            )
          );
        };
        "value" = mkOption {
          description = "Value matches the exact value of the header. Can be specified either\nalone or together with \"Secret\"; will be used as the header value if the\nsecret can not be found in the latter case.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "mismatch" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesHttpHeaderMatchesSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsRulesKafka" = {

      options = {
        "apiKey" = mkOption {
          description = "APIKey is a case-insensitive string matched against the key of a\nrequest, e.g. \"produce\", \"fetch\", \"createtopic\", \"deletetopic\", et al\nReference: https://kafka.apache.org/protocol#protocol_api_keys\n\nIf omitted or empty, and if Role is not specified, then all keys are allowed.";
          type = (types.nullOr types.str);
        };
        "apiVersion" = mkOption {
          description = "APIVersion is the version matched against the api version of the\nKafka message. If set, it has to be a string representing a positive\ninteger.\n\nIf omitted or empty, all versions are allowed.";
          type = (types.nullOr types.str);
        };
        "clientID" = mkOption {
          description = "ClientID is the client identifier as provided in the request.\n\nFrom Kafka protocol documentation:\nThis is a user supplied identifier for the client application. The\nuser can use any identifier they like and it will be used when\nlogging errors, monitoring aggregates, etc. For example, one might\nwant to monitor not just the requests per second overall, but the\nnumber coming from each client application (each of which could\nreside on multiple servers). This id acts as a logical grouping\nacross all requests from a particular client.\n\nIf omitted or empty, all client identifiers are allowed.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a case-insensitive string and describes a group of API keys\nnecessary to perform certain higher-level Kafka operations such as \"produce\"\nor \"consume\". A Role automatically expands into all APIKeys required\nto perform the specified higher-level operation.\n\nThe following values are supported:\n - \"produce\": Allow producing to the topics specified in the rule\n - \"consume\": Allow consuming from the topics specified in the rule\n\nThis field is incompatible with the APIKey field, i.e APIKey and Role\ncannot both be specified in the same rule.\n\nIf omitted or empty, and if APIKey is not specified, then all keys are\nallowed.";
          type = (types.nullOr types.str);
        };
        "topic" = mkOption {
          description = "Topic is the topic name contained in the message. If a Kafka request\ncontains multiple topics, then all topics must be allowed or the\nmessage will be rejected.\n\nThis constraint is ignored if the matched request message type\ndoesn't contain any topic. Maximum size of Topic can be 249\ncharacters as per recent Kafka spec and allowed characters are\na-z, A-Z, 0-9, -, . and _.\n\nOlder Kafka versions had longer topic lengths of 255, but in Kafka 0.10\nversion the length was changed from 255 to 249. For compatibility\nreasons we are using 255.\n\nIf omitted or empty, all topics are allowed.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "apiVersion" = mkOverride 1002 null;
        "clientID" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "topic" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsTerminatingTLS" = {

      options = {
        "certificate" = mkOption {
          description = "Certificate is the file name or k8s secret item name for the certificate\nchain. If omitted, 'tls.crt' is assumed, if it exists. If given, the\nitem must exist.";
          type = (types.nullOr types.str);
        };
        "privateKey" = mkOption {
          description = "PrivateKey is the file name or k8s secret item name for the private key\nmatching the certificate chain. If omitted, 'tls.key' is assumed, if it\nexists. If given, the item must exist.";
          type = (types.nullOr types.str);
        };
        "secret" = mkOption {
          description = "Secret is the secret that contains the certificates and private key for\nthe TLS context.\nBy default, Cilium will search in this secret for the following items:\n - 'ca.crt'  - Which represents the trusted CA to verify remote source.\n - 'tls.crt' - Which represents the public key certificate.\n - 'tls.key' - Which represents the private key matching the public key\n               certificate.";
          type = (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsTerminatingTLSSecret");
        };
        "trustedCA" = mkOption {
          description = "TrustedCA is the file name or k8s secret item name for the trusted CA.\nIf omitted, 'ca.crt' is assumed, if it exists. If given, the item must\nexist.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "certificate" = mkOverride 1002 null;
        "privateKey" = mkOverride 1002 null;
        "trustedCA" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsIngressToPortsTerminatingTLSSecret" = {

      options = {
        "name" = mkOption {
          description = "Name is the name of the secret.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace is the namespace in which the secret exists. Context of use\ndetermines the default value if left out (e.g., \"default\").";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsLabels" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "source" = mkOption {
          description = "Source can be one of the above values (e.g.: LabelSourceContainer).";
          type = (types.nullOr types.str);
        };
        "value" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "source" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsLog" = {

      options = {
        "value" = mkOption {
          description = "Value is a free-form string that is included in Hubble flows\nthat match this policy. The string is limited to 32 printable characters.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicySpecsNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicySpecsNodeSelectorMatchExpressions")
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
    "cilium.io.v2.CiliumNetworkPolicySpecsNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2.CiliumNetworkPolicyStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = (
            types.nullOr (types.listOf (submoduleOf "cilium.io.v2.CiliumNetworkPolicyStatusConditions"))
          );
        };
        "derivativePolicies" = mkOption {
          description = "DerivativePolicies is the status of all policies derived from the Cilium\npolicy";
          type = (types.nullOr (types.attrsOf types.attrs));
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "derivativePolicies" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2.CiliumNetworkPolicyStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "The last time the condition transitioned from one status to another.";
          type = (types.nullOr types.str);
        };
        "message" = mkOption {
          description = "A human readable message indicating details about the transition.";
          type = (types.nullOr types.str);
        };
        "reason" = mkOption {
          description = "The reason for the condition's last transition.";
          type = (types.nullOr types.str);
        };
        "status" = mkOption {
          description = "The status of the condition, one of True, False, or Unknown";
          type = types.str;
        };
        "type" = mkOption {
          description = "The type of the policy condition";
          type = types.str;
        };
      };

      config = {
        "lastTransitionTime" = mkOverride 1002 null;
        "message" = mkOverride 1002 null;
        "reason" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicy" = {

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
          type = (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "Spec is a human readable description of a L2 announcement policy";
          type = (types.nullOr (submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpec"));
        };
        "status" = mkOption {
          description = "Status is the status of the policy.";
          type = (types.nullOr (submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicyStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpec" = {

      options = {
        "externalIPs" = mkOption {
          description = "If true, the external IPs of the services are announced";
          type = (types.nullOr types.bool);
        };
        "interfaces" = mkOption {
          description = "A list of regular expressions that express which network interface(s) should be used\nto announce the services over. If nil, all network interfaces are used.";
          type = (types.nullOr (types.listOf types.str));
        };
        "loadBalancerIPs" = mkOption {
          description = "If true, the loadbalancer IPs of the services are announced\n\nIf nil this policy applies to all services.";
          type = (types.nullOr types.bool);
        };
        "nodeSelector" = mkOption {
          description = "NodeSelector selects a group of nodes which will announce the IPs for\nthe services selected by the service selector.\n\nIf nil this policy applies to all nodes.";
          type = (types.nullOr (submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecNodeSelector"));
        };
        "serviceSelector" = mkOption {
          description = "ServiceSelector selects a set of services which will be announced over L2 networks.\nThe loadBalancerClass for a service must be nil or specify a supported class, e.g.\n\"io.cilium/l2-announcer\". Refer to the following document for additional details\nregarding load balancer classes:\n\n  https://kubernetes.io/docs/concepts/services-networking/service/#load-balancer-class\n\nIf nil this policy applies to all services.";
          type = (
            types.nullOr (submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecServiceSelector")
          );
        };
      };

      config = {
        "externalIPs" = mkOverride 1002 null;
        "interfaces" = mkOverride 1002 null;
        "loadBalancerIPs" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "serviceSelector" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecNodeSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecNodeSelectorMatchExpressions"
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
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecNodeSelectorMatchExpressions" = {

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
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecServiceSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecServiceSelectorMatchExpressions"
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
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicySpecServiceSelectorMatchExpressions" = {

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
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicyStatus" = {

      options = {
        "conditions" = mkOption {
          description = "Current service state";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "cilium.io.v2alpha1.CiliumL2AnnouncementPolicyStatusConditions")
            )
          );
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };

    };
    "cilium.io.v2alpha1.CiliumL2AnnouncementPolicyStatusConditions" = {

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

  };
in
{
  # all resource versions
  options = {
    resources = {
      "cilium.io"."v2"."CiliumBGPAdvertisement" = mkOption {
        description = "CiliumBGPAdvertisement is the Schema for the ciliumbgpadvertisements API";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPAdvertisement" "ciliumbgpadvertisements"
              "CiliumBGPAdvertisement"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumBGPClusterConfig" = mkOption {
        description = "CiliumBGPClusterConfig is the Schema for the CiliumBGPClusterConfig API";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPClusterConfig" "ciliumbgpclusterconfigs"
              "CiliumBGPClusterConfig"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumBGPNodeConfigOverride" = mkOption {
        description = "CiliumBGPNodeConfigOverride specifies configuration overrides for a CiliumBGPNodeConfig.\nIt allows fine-tuning of BGP behavior on a per-node basis. For the override to be effective,\nthe names in CiliumBGPNodeConfigOverride and CiliumBGPNodeConfig must match exactly. This\nmatching ensures that specific node configurations are applied correctly and only where intended.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPNodeConfigOverride" "ciliumbgpnodeconfigoverrides"
              "CiliumBGPNodeConfigOverride"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumBGPPeerConfig" = mkOption {
        description = "";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPPeerConfig" "ciliumbgppeerconfigs"
              "CiliumBGPPeerConfig"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumClusterwideNetworkPolicy" = mkOption {
        description = "CiliumClusterwideNetworkPolicy is a Kubernetes third-party resource with an\nmodified version of CiliumNetworkPolicy which is cluster scoped rather than\nnamespace scoped.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumClusterwideNetworkPolicy"
              "ciliumclusterwidenetworkpolicies"
              "CiliumClusterwideNetworkPolicy"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumLoadBalancerIPPool" = mkOption {
        description = "CiliumLoadBalancerIPPool is a Kubernetes third-party resource which\nis used to defined pools of IPs which the operator can use to to allocate\nand advertise IPs for Services of type LoadBalancer.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumLoadBalancerIPPool" "ciliumloadbalancerippools"
              "CiliumLoadBalancerIPPool"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2"."CiliumNetworkPolicy" = mkOption {
        description = "CiliumNetworkPolicy is a Kubernetes third-party resource with an extended\nversion of NetworkPolicy.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumNetworkPolicy" "ciliumnetworkpolicies"
              "CiliumNetworkPolicy"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "cilium.io"."v2alpha1"."CiliumL2AnnouncementPolicy" = mkOption {
        description = "CiliumL2AnnouncementPolicy is a Kubernetes third-party resource which\nis used to defined which nodes should announce what services on the\nL2 network.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2alpha1.CiliumL2AnnouncementPolicy"
              "ciliuml2announcementpolicies"
              "CiliumL2AnnouncementPolicy"
              "cilium.io"
              "v2alpha1"
          )
        );
        default = { };
      };

    }
    // {
      "ciliumBGPAdvertisements" = mkOption {
        description = "CiliumBGPAdvertisement is the Schema for the ciliumbgpadvertisements API";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPAdvertisement" "ciliumbgpadvertisements"
              "CiliumBGPAdvertisement"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumBGPClusterConfigs" = mkOption {
        description = "CiliumBGPClusterConfig is the Schema for the CiliumBGPClusterConfig API";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPClusterConfig" "ciliumbgpclusterconfigs"
              "CiliumBGPClusterConfig"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumBGPNodeConfigOverrides" = mkOption {
        description = "CiliumBGPNodeConfigOverride specifies configuration overrides for a CiliumBGPNodeConfig.\nIt allows fine-tuning of BGP behavior on a per-node basis. For the override to be effective,\nthe names in CiliumBGPNodeConfigOverride and CiliumBGPNodeConfig must match exactly. This\nmatching ensures that specific node configurations are applied correctly and only where intended.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPNodeConfigOverride" "ciliumbgpnodeconfigoverrides"
              "CiliumBGPNodeConfigOverride"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumBGPPeerConfigs" = mkOption {
        description = "";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumBGPPeerConfig" "ciliumbgppeerconfigs"
              "CiliumBGPPeerConfig"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumClusterwideNetworkPolicies" = mkOption {
        description = "CiliumClusterwideNetworkPolicy is a Kubernetes third-party resource with an\nmodified version of CiliumNetworkPolicy which is cluster scoped rather than\nnamespace scoped.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumClusterwideNetworkPolicy"
              "ciliumclusterwidenetworkpolicies"
              "CiliumClusterwideNetworkPolicy"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumL2AnnouncementPolicies" = mkOption {
        description = "CiliumL2AnnouncementPolicy is a Kubernetes third-party resource which\nis used to defined which nodes should announce what services on the\nL2 network.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2alpha1.CiliumL2AnnouncementPolicy"
              "ciliuml2announcementpolicies"
              "CiliumL2AnnouncementPolicy"
              "cilium.io"
              "v2alpha1"
          )
        );
        default = { };
      };
      "ciliumLoadBalancerIPPools" = mkOption {
        description = "CiliumLoadBalancerIPPool is a Kubernetes third-party resource which\nis used to defined pools of IPs which the operator can use to to allocate\nand advertise IPs for Services of type LoadBalancer.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumLoadBalancerIPPool" "ciliumloadbalancerippools"
              "CiliumLoadBalancerIPPool"
              "cilium.io"
              "v2"
          )
        );
        default = { };
      };
      "ciliumNetworkPolicies" = mkOption {
        description = "CiliumNetworkPolicy is a Kubernetes third-party resource with an extended\nversion of NetworkPolicy.";
        type = (
          types.attrsOf (
            submoduleForDefinition "cilium.io.v2.CiliumNetworkPolicy" "ciliumnetworkpolicies"
              "CiliumNetworkPolicy"
              "cilium.io"
              "v2"
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
        name = "ciliumbgpadvertisements";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumBGPAdvertisement";
        attrName = "ciliumBGPAdvertisements";
      }
      {
        name = "ciliumbgpclusterconfigs";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumBGPClusterConfig";
        attrName = "ciliumBGPClusterConfigs";
      }
      {
        name = "ciliumbgpnodeconfigoverrides";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumBGPNodeConfigOverride";
        attrName = "ciliumBGPNodeConfigOverrides";
      }
      {
        name = "ciliumbgppeerconfigs";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumBGPPeerConfig";
        attrName = "ciliumBGPPeerConfigs";
      }
      {
        name = "ciliumclusterwidenetworkpolicies";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumClusterwideNetworkPolicy";
        attrName = "ciliumClusterwideNetworkPolicies";
      }
      {
        name = "ciliumloadbalancerippools";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumLoadBalancerIPPool";
        attrName = "ciliumLoadBalancerIPPools";
      }
      {
        name = "ciliumnetworkpolicies";
        group = "cilium.io";
        version = "v2";
        kind = "CiliumNetworkPolicy";
        attrName = "ciliumNetworkPolicies";
      }
      {
        name = "ciliuml2announcementpolicies";
        group = "cilium.io";
        version = "v2alpha1";
        kind = "CiliumL2AnnouncementPolicy";
        attrName = "ciliumL2AnnouncementPolicies";
      }
    ];

    resources = {
      "cilium.io"."v2"."CiliumBGPAdvertisement" =
        mkAliasDefinitions
          options.resources."ciliumBGPAdvertisements";
      "cilium.io"."v2"."CiliumBGPClusterConfig" =
        mkAliasDefinitions
          options.resources."ciliumBGPClusterConfigs";
      "cilium.io"."v2"."CiliumBGPNodeConfigOverride" =
        mkAliasDefinitions
          options.resources."ciliumBGPNodeConfigOverrides";
      "cilium.io"."v2"."CiliumBGPPeerConfig" =
        mkAliasDefinitions
          options.resources."ciliumBGPPeerConfigs";
      "cilium.io"."v2"."CiliumClusterwideNetworkPolicy" =
        mkAliasDefinitions
          options.resources."ciliumClusterwideNetworkPolicies";
      "cilium.io"."v2alpha1"."CiliumL2AnnouncementPolicy" =
        mkAliasDefinitions
          options.resources."ciliumL2AnnouncementPolicies";
      "cilium.io"."v2"."CiliumLoadBalancerIPPool" =
        mkAliasDefinitions
          options.resources."ciliumLoadBalancerIPPools";
      "cilium.io"."v2"."CiliumNetworkPolicy" =
        mkAliasDefinitions
          options.resources."ciliumNetworkPolicies";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "cilium.io";
        version = "v2";
        kind = "CiliumNetworkPolicy";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
