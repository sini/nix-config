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
    "bitnami.com.v1alpha1.SealedSecret" = {

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
          description = "SealedSecretSpec is the specification of a SealedSecret.";
          type = (submoduleOf "bitnami.com.v1alpha1.SealedSecretSpec");
        };
        "status" = mkOption {
          description = "SealedSecretStatus is the most recently observed status of the SealedSecret.";
          type = (types.nullOr (submoduleOf "bitnami.com.v1alpha1.SealedSecretStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "bitnami.com.v1alpha1.SealedSecretSpec" = {

      options = {
        "data" = mkOption {
          description = "Data is deprecated and will be removed eventually. Use per-value EncryptedData instead.";
          type = (types.nullOr types.str);
        };
        "encryptedData" = mkOption {
          description = "";
          type = (types.attrsOf types.str);
        };
        "template" = mkOption {
          description = "Template defines the structure of the Secret that will be\ncreated from this sealed secret.";
          type = (types.nullOr (submoduleOf "bitnami.com.v1alpha1.SealedSecretSpecTemplate"));
        };
      };

      config = {
        "data" = mkOverride 1002 null;
        "template" = mkOverride 1002 null;
      };

    };
    "bitnami.com.v1alpha1.SealedSecretSpecTemplate" = {

      options = {
        "data" = mkOption {
          description = "Keys that should be templated using decrypted data.";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "immutable" = mkOption {
          description = "Immutable, if set to true, ensures that data stored in the Secret cannot\nbe updated (only object metadata can be modified).\nIf not set to true, the field can be modified at any time.\nDefaulted to nil.";
          type = (types.nullOr types.bool);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata.\nMore info: https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata";
          type = (types.nullOr (submoduleOf "bitnami.com.v1alpha1.SealedSecretSpecTemplateMetadata"));
        };
        "type" = mkOption {
          description = "Used to facilitate programmatic handling of secret data.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "data" = mkOverride 1002 null;
        "immutable" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "bitnami.com.v1alpha1.SealedSecretSpecTemplateMetadata" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "finalizers" = mkOption {
          description = "";
          type = (types.nullOr (types.listOf types.str));
        };
        "labels" = mkOption {
          description = "";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "name" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "namespace" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "finalizers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "bitnami.com.v1alpha1.SealedSecretStatus" = {

      options = {
        "conditions" = mkOption {
          description = "Represents the latest available observations of a sealed secret's current state.";
          type = (
            types.nullOr (types.listOf (submoduleOf "bitnami.com.v1alpha1.SealedSecretStatusConditions"))
          );
        };
        "observedGeneration" = mkOption {
          description = "ObservedGeneration reflects the generation most recently observed by the sealed-secrets controller.";
          type = (types.nullOr types.int);
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "bitnami.com.v1alpha1.SealedSecretStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "Last time the condition transitioned from one status to another.";
          type = (types.nullOr types.str);
        };
        "lastUpdateTime" = mkOption {
          description = "The last time this condition was updated.";
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
          description = "Status of the condition for a sealed secret.\nValid values for \"Synced\": \"True\", \"False\", or \"Unknown\".";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of condition for a sealed secret.\nValid value: \"Synced\"";
          type = types.str;
        };
      };

      config = {
        "lastTransitionTime" = mkOverride 1002 null;
        "lastUpdateTime" = mkOverride 1002 null;
        "message" = mkOverride 1002 null;
        "reason" = mkOverride 1002 null;
      };

    };

  };
in
{
  # all resource versions
  options = {
    resources = {
      "bitnami.com"."v1alpha1"."SealedSecret" = mkOption {
        description = "SealedSecret is the K8s representation of a \"sealed Secret\" - a\nregular k8s Secret that has been sealed (encrypted) using the\ncontroller's key.";
        type = (
          types.attrsOf (
            submoduleForDefinition "bitnami.com.v1alpha1.SealedSecret" "sealedsecrets" "SealedSecret"
              "bitnami.com"
              "v1alpha1"
          )
        );
        default = { };
      };

    }
    // {
      "sealedSecrets" = mkOption {
        description = "SealedSecret is the K8s representation of a \"sealed Secret\" - a\nregular k8s Secret that has been sealed (encrypted) using the\ncontroller's key.";
        type = (
          types.attrsOf (
            submoduleForDefinition "bitnami.com.v1alpha1.SealedSecret" "sealedsecrets" "SealedSecret"
              "bitnami.com"
              "v1alpha1"
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
        name = "sealedsecrets";
        group = "bitnami.com";
        version = "v1alpha1";
        kind = "SealedSecret";
        attrName = "sealedSecrets";
      }
    ];

    resources = {
      "bitnami.com"."v1alpha1"."SealedSecret" = mkAliasDefinitions options.resources."sealedSecrets";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "bitnami.com";
        version = "v1alpha1";
        kind = "SealedSecret";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
