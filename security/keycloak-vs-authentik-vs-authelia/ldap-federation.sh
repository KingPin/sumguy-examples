#!/usr/bin/env bash
# Create a "home" realm and attach a read-only LDAP user federation provider.
# Run from this directory after `docker compose up -d` and once Keycloak is ready:
#   KC_ADMIN_PASSWORD=... LDAP_BIND_PASSWORD=... ./ldap-federation.sh
set -euo pipefail

: "${KC_ADMIN_PASSWORD:?set KC_ADMIN_PASSWORD (the bootstrap admin password)}"
: "${LDAP_BIND_PASSWORD:?set LDAP_BIND_PASSWORD}"

docker compose exec -T \
  -e KC_ADMIN_PASSWORD="$KC_ADMIN_PASSWORD" \
  -e LDAP_BIND_PASSWORD="$LDAP_BIND_PASSWORD" \
  keycloak bash -s <<'EOF'
set -euo pipefail
KCADM=/opt/keycloak/bin/kcadm.sh
$KCADM config credentials --server http://localhost:8080 --realm master \
  --user admin --password "$KC_ADMIN_PASSWORD"

$KCADM create realms -s realm=home -s enabled=true
REALM_ID=$($KCADM get realms/home --fields id --format csv --noquotes)

$KCADM create components -r home \
  -s name=corp-ldap -s providerId=ldap \
  -s providerType=org.keycloak.storage.UserStorageProvider \
  -s parentId="$REALM_ID" \
  -s 'config.vendor=["other"]' \
  -s 'config.connectionUrl=["ldap://ldap.example.com:389"]' \
  -s 'config.usersDn=["ou=people,dc=example,dc=com"]' \
  -s 'config.bindDn=["cn=svc-keycloak,dc=example,dc=com"]' \
  -s "config.bindCredential=[\"$LDAP_BIND_PASSWORD\"]" \
  -s 'config.authType=["simple"]' \
  -s 'config.usernameLDAPAttribute=["uid"]' \
  -s 'config.rdnLDAPAttribute=["uid"]' \
  -s 'config.uuidLDAPAttribute=["entryUUID"]' \
  -s 'config.userObjectClasses=["inetOrgPerson, organizationalPerson"]' \
  -s 'config.editMode=["READ_ONLY"]'
EOF
