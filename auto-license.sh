#!/usr/bin/env bash

# Script that sends tha Kong license to stdout. The license will be downloaded
# from Pulp.
#
# Inputs:
#   stdin, or PULP_PASSWORD env var: required
#   PULP_USERNAME env var, defaults to 'admin' if not set
#
# Dependencies:
#   curl: required
#   jq: optional, will print some license details if available

function main {
  local KONG_PULP_PASSWORD
  local KONG_PULP_USERNAME=admin
  local KONG_PULP_URL="https://download.konghq.com/internal/kong-gateway/license.json"
  local KONG_LICENSE_DATA

  if ! curl --version > /dev/null ; then
    echo "[ERROR] required dependency 'curl' missing" 1>&2
    exit 1
  fi

  if [ -t 0 ]; then
    # running interactively
    if [ -z "$PULP_PASSWORD" ]; then
      echo "PULP_PASSWORD not set, nor passed in on STDIN" 1>&2
      exit 1
    fi
    KONG_PULP_PASSWORD=$PULP_PASSWORD
  else
    # pipe stdin; read password
    IFS= read -r KONG_PULP_PASSWORD
  fi

  if [ -n "$PULP_USERNAME" ]; then
    KONG_PULP_USERNAME=$PULP_USERNAME
  fi


  KONG_LICENSE_DATA=$(curl -s -L --retry 3 --retry-delay 3 -u"$KONG_PULP_USERNAME:$KONG_PULP_PASSWORD" "$KONG_PULP_URL")
  if [[ ! $KONG_LICENSE_DATA == *"signature"* || ! $KONG_LICENSE_DATA == *"payload"* ]]; then
    echo "[ERROR] failed to download the Kong Enterprise license file
$KONG_LICENSE_DATA" 1>&2
    exit 1
  fi
 
  if jq --version &> /dev/null ; then
    # jq is installed so do some pretty printing of license info (to STDERR)
    local PRODUCT=$(jq -r '.license.payload.product_subscription' <<< "$KONG_LICENSE_DATA")
    local COMPANY=$(jq -r '.license.payload.customer' <<< "$KONG_LICENSE_DATA")
    local EXPIRE=$(jq -r '.license.payload.license_expiration_date' <<< "$KONG_LICENSE_DATA")
    echo "$PRODUCT licensed to $COMPANY, license expires: $EXPIRE" 1>&2
  fi

  echo "$KONG_LICENSE_DATA"
}

main
