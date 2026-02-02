# Age key creation

Age key is stored on a yubikey, but generated off card and stored in a secure encrypted backup so that the key can be loaded to multiple cards (home + mobile).
Instructions reproduced here for ease of reference, taken from discussion here: https://github.com/str4d/age-plugin-yubikey/issues/75#issuecomment-2424343192

```
$ cat age-plugin-yubikey.cnf
[ req ]
distinguished_name        = req_distinguished_name
x509_extensions           = v3_req
prompt = no

[ req_distinguished_name ]
0.organizationName        = age-plugin-yubikey
organizationalUnitName    = 0.5.0
commonName                = something something (age)

[ v3_req ]
subjectKeyIdentifier      = hash
1.3.6.1.4.1.41482.3.8     = DER:0101

#            PinPolicy::Default => 0,
#            PinPolicy::Never => 1,
#            PinPolicy::Once => 2,
#            PinPolicy::Always => 3,

#            TouchPolicy::Default => 0,
#            TouchPolicy::Never => 1,
#            TouchPolicy::Always => 2,
#            TouchPolicy::Cached => 3,
```

```
$ cat build.sh
#!/bin/bash

set -o errexit

CNF="age-plugin-yubikey.cnf"
KEY="age.key.pem"
CRT="age.cert.pem"
CSR="age.csr"
PIN="123456"
SERIAL="99999999"

# DONT OVERWRITE KEY
# openssl ecparam -name prime256v1 -genkey -noout -out $KEY
openssl req -config $CNF -new -key $KEY -out $CSR
openssl x509 -req -sha256 -days 3650 -in $CSR -signkey $KEY -out $CRT -extfile $CNF -extensions v3_req
openssl x509 -in $CRT -text -certopt ext_dump -noout

ykman piv certificates import 82 $CRT --pin $PIN
ykman piv keys import 82 --pin-policy NEVER --touch-policy NEVER $KEY --pin $PIN

age-plugin-yubikey -l
age-plugin-yubikey -i --serial $SERIAL --slot 1 > age-identity.txt
cat foo.txt.age | age -d -i age-identity.txt
```


# Notes:

* Decrypt:
age --decrypt -i .secrets/pub/master.pub FILE.age

* Encrypt:
age -r ${pub_key} -e data.txt > data.txt.age

sops --encrypt \
  -age $pub_key \
  --output secret-enc.yaml \
  secret.yaml
