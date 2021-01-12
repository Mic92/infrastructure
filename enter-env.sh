#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bashInteractive vault awscli jq openssh

set -eu

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
function finish {
  rm -rf "$scratch"
  if [ "x${VAULT_EXIT_ACCESSOR:-}" != "x" ]; then
    echo "--> Revoking my token ..." >&2
    vault token revoke -self
  fi
}
trap finish EXIT

echo "--> Assuming role: ofborg-deployers" >&2
vault_creds=$(vault token create \
	-display-name=ofborg-infrastructure \
	-format=json \
	-role ofborg-deployers)

VAULT_EXIT_ACCESSOR=$(jq -r .auth.accessor <<<"$vault_creds")
expiration_ts=$(($(date '+%s') + "$(jq -r .auth.lease_duration<<<"$vault_creds")"))
export VAULT_TOKEN=$(jq -r .auth.client_token <<<"$vault_creds")

echo "--> Setting variables: PACKET_AUTH_TOKEN, CLOUDAMQP_APIKEY, AWS_ACCESS_KEY_ID" >&2
echo "                       AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN" >&2
export PACKET_AUTH_TOKEN=$(vault kv get -field api_key_token packet/creds/nixos-foundation)
export CLOUDAMQP_APIKEY=$(vault kv get -field key secret/ofborg/cloudamqp.key)

aws_creds=$(vault kv get -format=json aws-personal/creds/state-ofborg)
export AWS_ACCESS_KEY_ID=$(jq -r .data.access_key <<<"$aws_creds")
export AWS_SECRET_ACCESS_KEY=$(jq -r .data.secret_key <<<"$aws_creds")
export AWS_SESSION_TOKEN=$(jq -r .data.security_token <<<"$aws_creds")
if [ -z "$AWS_SESSION_TOKEN" ] ||  [ "$AWS_SESSION_TOKEN" == "null" ]; then
  unset AWS_SESSION_TOKEN
fi

echo "--> Preflight testing the AWS credentials..." >&2
for  i in $(seq 1 100); do
  if aws sts get-caller-identity > /dev/null; then
    break;
  else
    echo "    Trying again in 1s..." >&2
    sleep 1
  fi
done

unset aws_creds

vault kv get -field=expression secret/ofborg/local.nix > ./private/local.nix
vault kv get -field=key secret/ofborg/github.key > ./private/github.key

echo "--> Signing SSH key deploy.key.pub -> deploy.key-cert.pub" >&2
if [ ! -f deploy.key ]; then
  ssh-keygen -t rsa -f deploy.key -N ""
fi

vault write -field=signed_key \
  ssh-keys-ofborg/sign/root public_key=@./deploy.key.pub > deploy.key-cert.pub
export SSH_IDENTITY_FILE=$(pwd)/deploy.key
export SSH_USER=root

if [ "x${1:-}" == "x" ]; then

cat <<BASH > "$scratch/bashrc"
vault_prompt() {
  remaining=\$(( $expiration_ts - \$(date '+%s')))
  if [ \$remaining -gt 0 ]; then
    PS1='\n\[\033[01;32m\][TTL:\${remaining}s:\w]\$\[\033[0m\] ';
  else
    remaining=expired
    PS1='\n\[\033[01;33m\][\$remaining:\w]\$\[\033[0m\] ';
  fi
}
PROMPT_COMMAND=vault_prompt
BASH

bash --init-file "$scratch/bashrc"
else
  "$@"
fi

