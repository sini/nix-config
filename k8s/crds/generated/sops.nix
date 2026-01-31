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
    "isindir.github.com.v1alpha3.SopsSecret" = {

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
        "sops" = mkOption {
          description = "SopsSecret metadata";
          type = (types.nullOr (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSops"));
        };
        "spec" = mkOption {
          description = "SopsSecret Spec definition";
          type = (types.nullOr (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSpec"));
        };
        "status" = mkOption {
          description = "SopsSecret Status information";
          type = (types.nullOr (submoduleOf "isindir.github.com.v1alpha3.SopsSecretStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "sops" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSops" = {

      options = {
        "age" = mkOption {
          description = "Age configuration";
          type = (types.nullOr (types.listOf (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSopsAge")));
        };
        "azure_kv" = mkOption {
          description = "Azure KMS configuration";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey "isindir.github.com.v1alpha3.SopsSecretSopsAzure_kv" "name" [ ]
            )
          );
          apply = attrsToList;
        };
        "encrypted_regex" = mkOption {
          description = "Regex used to encrypt SopsSecret resource\nThis opstion should be used with more care, as it can make resource unapplicable to the cluster.";
          type = (types.nullOr types.str);
        };
        "encrypted_suffix" = mkOption {
          description = "Suffix used to encrypt SopsSecret resource";
          type = (types.nullOr types.str);
        };
        "gcp_kms" = mkOption {
          description = "Gcp KMS configuration";
          type = (
            types.nullOr (types.listOf (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSopsGcp_kms"))
          );
        };
        "hc_vault" = mkOption {
          description = "Hashicorp Vault KMS configurarion";
          type = (
            types.nullOr (types.listOf (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSopsHc_vault"))
          );
        };
        "kms" = mkOption {
          description = "Aws KMS configuration";
          type = (types.nullOr (types.listOf (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSopsKms")));
        };
        "lastmodified" = mkOption {
          description = "LastModified date when SopsSecret was last modified";
          type = (types.nullOr types.str);
        };
        "mac" = mkOption {
          description = "Mac - sops setting";
          type = (types.nullOr types.str);
        };
        "pgp" = mkOption {
          description = "PGP configuration";
          type = (types.nullOr (types.listOf (submoduleOf "isindir.github.com.v1alpha3.SopsSecretSopsPgp")));
        };
        "version" = mkOption {
          description = "Version of the sops tool used to encrypt SopsSecret";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "age" = mkOverride 1002 null;
        "azure_kv" = mkOverride 1002 null;
        "encrypted_regex" = mkOverride 1002 null;
        "encrypted_suffix" = mkOverride 1002 null;
        "gcp_kms" = mkOverride 1002 null;
        "hc_vault" = mkOverride 1002 null;
        "kms" = mkOverride 1002 null;
        "lastmodified" = mkOverride 1002 null;
        "mac" = mkOverride 1002 null;
        "pgp" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsAge" = {

      options = {
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "recipient" = mkOption {
          description = "Recipient which private key can be used for decription";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "enc" = mkOverride 1002 null;
        "recipient" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsAzure_kv" = {

      options = {
        "created_at" = mkOption {
          description = "Object creation date";
          type = (types.nullOr types.str);
        };
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "name" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "vault_url" = mkOption {
          description = "Azure KMS vault URL";
          type = (types.nullOr types.str);
        };
        "version" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "created_at" = mkOverride 1002 null;
        "enc" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "vault_url" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsGcp_kms" = {

      options = {
        "created_at" = mkOption {
          description = "Object creation date";
          type = (types.nullOr types.str);
        };
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "resource_id" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "created_at" = mkOverride 1002 null;
        "enc" = mkOverride 1002 null;
        "resource_id" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsHc_vault" = {

      options = {
        "created_at" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "engine_path" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "key_name" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "vault_address" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "created_at" = mkOverride 1002 null;
        "enc" = mkOverride 1002 null;
        "engine_path" = mkOverride 1002 null;
        "key_name" = mkOverride 1002 null;
        "vault_address" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsKms" = {

      options = {
        "arn" = mkOption {
          description = "Arn - KMS key ARN to use";
          type = (types.nullOr types.str);
        };
        "aws_profile" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "created_at" = mkOption {
          description = "Object creation date";
          type = (types.nullOr types.str);
        };
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "AWS Iam Role";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "arn" = mkOverride 1002 null;
        "aws_profile" = mkOverride 1002 null;
        "created_at" = mkOverride 1002 null;
        "enc" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSopsPgp" = {

      options = {
        "created_at" = mkOption {
          description = "Object creation date";
          type = (types.nullOr types.str);
        };
        "enc" = mkOption {
          description = "";
          type = (types.nullOr types.str);
        };
        "fp" = mkOption {
          description = "PGP FingerPrint of the key which can be used for decryption";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "created_at" = mkOverride 1002 null;
        "enc" = mkOverride 1002 null;
        "fp" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSpec" = {

      options = {
        "secretTemplates" = mkOption {
          description = "Secrets template is a list of definitions to create Kubernetes Secrets";
          type = (
            coerceAttrsOfSubmodulesToListByKey "isindir.github.com.v1alpha3.SopsSecretSpecSecretTemplates"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "suspend" = mkOption {
          description = "This flag tells the controller to suspend the reconciliation of this source.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "suspend" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretSpecSecretTemplates" = {

      options = {
        "annotations" = mkOption {
          description = "Annotations to apply to Kubernetes secret";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "data" = mkOption {
          description = "Data map to use in Kubernetes secret (equivalent to Kubernetes Secret object data, please see for more\ninformation: https://kubernetes.io/docs/concepts/configuration/secret/#overview-of-secrets)";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "labels" = mkOption {
          description = "Labels to apply to Kubernetes secret";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "name" = mkOption {
          description = "Name of the Kubernetes secret to create";
          type = types.str;
        };
        "stringData" = mkOption {
          description = "stringData map to use in Kubernetes secret (equivalent to Kubernetes Secret object stringData, please see for more\ninformation: https://kubernetes.io/docs/concepts/configuration/secret/#overview-of-secrets)";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "type" = mkOption {
          description = "Kubernetes secret type. Default: Opaque. Possible values: Opaque,\nkubernetes.io/service-account-token, kubernetes.io/dockercfg,\nkubernetes.io/dockerconfigjson, kubernetes.io/basic-auth,\nkubernetes.io/ssh-auth, kubernetes.io/tls, bootstrap.kubernetes.io/token";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "data" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "stringData" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "isindir.github.com.v1alpha3.SopsSecretStatus" = {

      options = {
        "message" = mkOption {
          description = "SopsSecret status message";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "message" = mkOverride 1002 null;
      };

    };

  };
in
{
  # all resource versions
  options = {
    resources = {
      "isindir.github.com"."v1alpha3"."SopsSecret" = mkOption {
        description = "SopsSecret is the Schema for the sopssecrets API";
        type = (
          types.attrsOf (
            submoduleForDefinition "isindir.github.com.v1alpha3.SopsSecret" "sopssecrets" "SopsSecret"
              "isindir.github.com"
              "v1alpha3"
          )
        );
        default = { };
      };

    }
    // {
      "sopsSecrets" = mkOption {
        description = "SopsSecret is the Schema for the sopssecrets API";
        type = (
          types.attrsOf (
            submoduleForDefinition "isindir.github.com.v1alpha3.SopsSecret" "sopssecrets" "SopsSecret"
              "isindir.github.com"
              "v1alpha3"
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
        name = "sopssecrets";
        group = "isindir.github.com";
        version = "v1alpha3";
        kind = "SopsSecret";
        attrName = "sopsSecrets";
      }
    ];

    resources = {
      "isindir.github.com"."v1alpha3"."SopsSecret" = mkAliasDefinitions options.resources."sopsSecrets";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "isindir.github.com";
        version = "v1alpha3";
        kind = "SopsSecret";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
