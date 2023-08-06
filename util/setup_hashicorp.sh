#!/usr/bin/env bash

set -x

vardir=$1
if [ -z "$vardir" ] ; then
  echo "ERROR: vardir should be defined as the first argument"
  exit 4
fi

. /etc/os-release

export VAULT_ADDR='http://127.0.0.1:8200'

killall vault

cat << EOF > $vardir/vault.hcl
storage "file" {
  path = "$vardir/vault_data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"

max_lease_ttl = "730h"
default_lease_ttl = "730h"
#max_versions=2
ui = true
log_level = "Trace"
disable_mlock = true
EOF

set -o pipefail

vault_arch=`uname -m`
if [ "$vault_arch" == "x86_64" ] ; then
  vault_arch="amd64"
elif [ "$vault_arch" == "aarch64" ] ; then
  vault_arch="arm64"
fi
cd /tmp
if ! [ -x /tmp/vault ] ; then
  if ! [ -e /tmp/vault.zip ] ; then
    wget https://releases.hashicorp.com/vault/1.10.4/vault_1.10.4_linux_${vault_arch}.zip -O /tmp/vault.zip
  fi
  unzip vault.zip
fi
if ! ./vault --version ; then
  echo "ERROR: Couldn't install vault from a zip file"
  exit 4
fi
./vault server --config=$vardir/vault.hcl &  

set -e

# restart exits too early, vault may be not ready yet
for i in 1 2 3 4 5 ; do
  sleep 2
  if ./vault operator init > $vardir/vault.init ; then
    break
  fi
done

./vault operator unseal `grep 'Unseal Key 1:' $vardir/vault.init | awk '{ print $4 }'`
./vault operator unseal `grep 'Unseal Key 2:' $vardir/vault.init | awk '{ print $4 }'`
./vault operator unseal `grep 'Unseal Key 3:' $vardir/vault.init | awk '{ print $4 }'`
export VAULT_TOKEN=`grep 'Initial Root Token:' $vardir/vault.init | awk '{ print $4 }'`
echo "$VAULT_TOKEN" > $vardir/vault.token
echo "$VAULT_ADDR" >> $vardir/vault.token

if ! ./vault login $VAULT_TOKEN ; then
  echo "ERROR: Could not login into the vault"
  exit 4
fi

echo "Checking the vault is working"
if    ./vault secrets disable mariadbtest && \
      ./vault secrets enable -path /mariadbtest -version=2 kv &&
      ./vault kv put /mariadbtest/1 data="123456789ABCDEF0123456789ABCDEF0" &&
      ./vault kv put /mariadbtest/2 data="23456789ABCDEF0123456789ABCDef01" &&
      ./vault kv put /mariadbtest/3 data="00000000000000000000000000000000" &&
      ./vault kv put /mariadbtest/3 data="00000000000000000000000000000001" &&
      ./vault kv put /mariadbtest/4 data="456789ABCDEF0123456789ABCDEF0123"
then
  ./vault secrets list
else
  echo "ERROR: Vault is not functioning properly after installation"
  exit 4

fi
