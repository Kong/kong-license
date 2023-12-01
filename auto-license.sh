#!/usr/bin/env bash

# Script that sends tha Kong license to stdout. The license will be downloaded
# from 1Password.
#
# Inputs: none
#
# Dependencies:
#   op: (1Password CLI) required
#   jq: optional, will print some license details if available

OP_UUID='ddwtjd6cmytlksanwl6xtkw23a'

# OnePassword account name
OP_ACCOUNT=team_kong

OP_SIGNIN_PARAMS="--account $OP_ACCOUNT --raw"
OP_GET_CMD="item get"

function main {
  local KONG_LICENSE_DATA

  # sign in to 1Password
  echo "Logging into 1Password..."
  OP_TOKEN=$(
    # shellcheck disable=SC2086
    op signin ${OP_SIGNIN_PARAMS}
  )
  if [[ ! $? == 0 ]]; then
    # an error while logging into 1Password
    echo "[ERROR] Failed to get a 1Password token, license data not updated."
    cleanup
    [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
  fi

  # Get the gateway license
  echo "Get license file from 1Password..."
  DETAILS=$(
    # shellcheck disable=SC2086
    op ${OP_GET_CMD} "$OP_UUID" --session "$OP_TOKEN" --format json
  )
  if [[ ! $? == 0 ]]; then
    # an error while fetching from 1p
    echo "[ERROR] Failed to get the data from 1Password, license data not updated."
    # sign out again
    op signout
    cleanup
    [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
  fi

  KONG_LICENSE_DATA="$DETAILS"
  if [[ ! ${KONG_LICENSE_DATA} == *"signature"* || ! ${KONG_LICENSE_DATA} == *"payload"* ]]; then
    echo "[ERROR] failed to download the Kong Enterprise license file
${KONG_LICENSE_DATA}" 1>&2
    return 1
  fi

  if ! jq <<<"${KONG_LICENSE_DATA}" &>/dev/null; then
    echo "[ERROR] downloaded Kong Enterprise license is not a valid JSON:
${KONG_LICENSE_DATA}" 1>&2
    return 1
  fi

  if jq --version &>/dev/null; then
    # jq is installed so do some pretty printing of license info (to STDERR)
    local PRODUCT=$(jq -r '.license.payload.product_subscription' <<<"${KONG_LICENSE_DATA}")
    local COMPANY=$(jq -r '.license.payload.customer' <<<"${KONG_LICENSE_DATA}")
    local EXPIRE=$(jq -r '.license.payload.license_expiration_date' <<<"${KONG_LICENSE_DATA}")
    echo "$PRODUCT licensed to $COMPANY, license expires: $EXPIRE" 1>&2
  fi

  echo "${KONG_LICENSE_DATA}"
}

# Add some basic retry mechanism to work around network flakiness and/or API misbehavior.
for _ in {1..3}; do
  if main; then
    exit 0
  fi
  sleep 3
done

# we failed
exit 1
