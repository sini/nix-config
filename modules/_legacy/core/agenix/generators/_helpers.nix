# Helper functions for TLS generators
{ lib, ... }:
{
  subject-string = subject: ''
    /C=${subject.country}\
    /ST=${subject.state}\
    /L=${subject.location}\
    /O=${subject.organization}\
    /OU=${subject.organizational-unit}'';

  validate-tls-settings =
    let
      inherit (lib) isAttrs isInt isString;
      inherit (lib.trivial) id throwIfNot;
    in
    name: tls:
    throwIfNot (isAttrs tls) "Secret '${name}' must have a `tls` attrset." throwIfNot
      (isString tls.domain)
      "Secret '${name}' must have a `tls.domain` string."
      throwIfNot
      (isInt tls.validity)
      "Secret '${name}' must have a `tls.validity` integer."
      (validate-tls-subject name tls.subject)
      id;

  validate-tls-subject =
    let
      inherit (lib) isAttrs isString;
      inherit (lib.trivial) id throwIfNot;
    in
    name: subject:
    throwIfNot (isAttrs subject) "Secret '${name}' must have a `tls.subject` attrset." throwIfNot
      (isString subject.country)
      "Secret '${name}' must have a `tls.subject.country` string."
      throwIfNot
      (isString subject.state)
      "Secret '${name}' must have a `tls.subject.state` string."
      throwIfNot
      (isString subject.location)
      "Secret '${name}' must have a `tls.subject.location` string."
      throwIfNot
      (isString subject.organization)
      "Secret '${name}' must have a `tls.subject.organization` string."
      throwIfNot
      (isString subject.organizational-unit)
      "Secret '${name}' must have a `tls.subject.organizational-unit` string."
      id;
}
