#!/usr/bin/env bash

# Account for different word splitting in zsh which doesn't split the words in
# variables causing errors like e.g.:
# unknown flag: --account team_kong --raw
#
# rel: https://zsh.sourceforge.io/Doc/Release/Options.html
function unset_zsh_opts() {
  if [[ "${SHELL}" =~ .*zsh$ && -n ${ZSH_NAME} ]]; then
    unsetopt SH_WORD_SPLIT
    trap - EXIT INT TERM
  fi
}
if [[ "${SHELL}" =~ .*zsh$ && -n ${ZSH_NAME} ]]; then
  setopt SH_WORD_SPLIT
  trap unset_zsh_opts EXIT INT TERM
fi

# location where to store our files
LOCATION="${HOME}/.kong-license-data"

# License file name
FILE='license.json'

# License entry uuid, use:
#   op item get --vault 'Github Actions' 'Monthly Kong Gateway Enterprise License' | grep 'ID:'
# to find the right uuid
OP_UUID='ddwtjd6cmytlksanwl6xtkw23a'

# Nothing to customize below
FILENAME="$LOCATION/$FILE"

function cleanup {
  unset LOCATION FILE OP_ACCOUNT FILENAME
  unset PRODUCT COMPANY EXPIRE
  unset EXPIRE_EPOCH NOW_EPOCH WARN_EPOCH EXPIRE_IN
  unset OP_UUID DETAILS
  unset NEW_KEY OLD_SIG NEW_SIG
  unset OP_SIGNIN_PARAMS OP_GET_CMD
  unset_zsh_opts
}

if [[ "$1" == "--help" ]]; then
  echo "Utility to automatically set the Kong Enterprise license"
  echo "environment variable 'KONG_LICENSE_DATA' from 1Password."
  echo
  echo "Prerequisites:"
  echo " - 'jq' installed, see https://stedolan.github.io/jq/"
  echo " - 1Password CLI installed (Version 2 is currently supported)"
  echo
  echo "Usage:"
  echo "    ${BASH_SOURCE[0]} [--help | --no-update | --update | --clean]"
  echo
  echo "    --update    : force update a non-expired license"
  echo "    --no-update : do not automatically try to update an expired license"
  echo "    --clean     : remove locally cached license file"
  echo "    --help      : display this help information"
  echo
  echo "For convenience you can add the following to your bash profile:"
  echo "    source ${BASH_SOURCE[0]} --no-update"
  echo
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

if [[ "$1" == "--clean" ]]; then
  rm "$FILENAME" >/dev/null 2>&1
  rmdir "$LOCATION" >/dev/null 2>&1
  echo "Removed cached files"
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

# Check 1Password CLI version
OP_VERSION=$(op --version)
if [[ $? -ne 0 ]]; then
  echo "The 1Password CLI utility 'op' was not found"
  echo "Please download and do the initial signin"
  echo
  echo "See: https://support.1password.com/command-line-getting-started/"
  echo
  echo "Use --help for info."
  echo
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

# Now established op CLI exists, need to set params for each version
# Set for op_CLIv2
OP_GET_CMD="item get"

# Crude version check and set parameters to match
if [[ $OP_VERSION == 1* ]]; then
  echo "[ERROR] Found 1Password CLI v1"
  echo "[ERROR] Please upgrade to v2"
  echo "[ERROR] https://1password.com/downloads/command-line/"
  echo
  cleanup
  exit 1
elif [[ $OP_VERSION != 2* ]]; then
  echo "The 1Password CLI utility 'op' version found is not supported by this script"
  echo "Currently supporting v1 (legacy) and v2 (latest as of 2022-05)"
  echo "Please download v2 and do the initial signin"
  echo
  echo "See: https://1password.com/downloads/command-line/"
  echo "and https://support.1password.com/command-line-getting-started/"
  echo
  echo "Use --help for info."
  echo
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

jq --version >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "Utility 'jq' was not found, please make sure it is installed"
  echo "and available in the system path."
  echo
  echo "See: https://stedolan.github.io/jq/"
  echo
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

# check if we're sourced or run
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  echo
  echo "[WARNING] running this script will check/update the locally cached"
  echo "license file, but will not export it as KONG_LICENSE_DATA."
  echo "To export it you must 'source' this script, e.g. run:"
  echo "    source ${BASH_SOURCE[0]} $*"
  echo
fi

# create directory if it doesn't exist
if [[ ! -d "$LOCATION" ]]; then
  mkdir "$LOCATION"
fi

# create outdated license if it doesn't exist
if [[ ! -f "$FILENAME" ]]; then
  cat >"$FILENAME" <<EOL
{"license":{"signature":"abf7652244fd9bee5fe385624f9e206425bdde6a27137f51dbfa2551971bea4f653e5b6364d66d42fb412df692ef43cf1694ccad047c413818c0149f56428e","payload":{"customer":"Kong Inc.","license_creation_date":"2018-11-15","product_subscription":"Kong Enterprise Edition","admin_seats":"50","support_plan":"None","license_expiration_date":"2019-01-01","license_key":"ASDASDASDASDASDASDASDASDASD_a1VASASD"},"version":1}}
EOL

  chmod +x "$FILENAME"
fi

# set the license data
export KONG_LICENSE_DATA=$(<"$FILENAME")
PRODUCT=$(jq -r '.license.payload.product_subscription' <<<"$KONG_LICENSE_DATA")
COMPANY=$(jq -r '.license.payload.customer' <<<"$KONG_LICENSE_DATA")
EXPIRE=$(jq -r '.license.payload.license_expiration_date' <<<"$KONG_LICENSE_DATA")
echo "$PRODUCT licensed to $COMPANY, license expires: $EXPIRE"

# Parsing date is platform specific
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  # unix variant
  EXPIRE_EPOCH=$(date --date="$EXPIRE" +%s)
else
  # assuming Mac
  EXPIRE_EPOCH=$(date -jf '%Y-%m-%d' "$EXPIRE" +%s)
fi

# add one day, because it expires at the end of the day
EXPIRE_EPOCH=$((EXPIRE_EPOCH + 86400))
NOW_EPOCH=$(date +%s)

# Parsing date is platform specific
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  # unix variant
  WARN_EPOCH=$(date -d "+10 days" +%s)
else
  # assuming Mac
  WARN_EPOCH=$(date -v +10d +%s)
fi

if ((NOW_EPOCH < EXPIRE_EPOCH)); then
  # license still valid
  if ((WARN_EPOCH > EXPIRE_EPOCH)); then
    # Expiry is within 10 days
    EXPIRE_IN=$((EXPIRE_EPOCH - NOW_EPOCH))
    EXPIRE_IN=$((EXPIRE_IN / 86400))
    printf '\e[1;33m%-6s\e[m' "[WARNING] The license will expire in less than $EXPIRE_IN days!"
    if [[ ! "$1" == "--update" ]]; then
      # only display instructions if we're not already updating
      echo
      echo "run the following command to initiate an update:"
      echo "    source ${BASH_SOURCE[0]} --update"
    fi
  fi

  # check if we're forcing an update, despite being valid
  if [[ ! "$1" == "--update" ]]; then
    # all is well, we're done
    cleanup
    [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
  fi

else
  # license expired
  printf '\e[1;31m%-6s\e[m' "[WARNING] The license has expired!"

  # Check if we need to skip updating, despite being outdated
  if [[ "$1" == "--no-update" ]]; then
    echo
    echo "run the following command to initiate an update:"
    echo "    source ${BASH_SOURCE[0]}"
    cleanup
    [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
  fi
fi

if {
  op whoami 2>&1 | grep -qs '@konghq.com'
} || {
  op account ls 2>&1 | grep -qs 'team-kong'
}; then
  echo 'Already signed into Kong 1Password account'
else
  echo

  # an error while logging into 1Password
  echo "[ERROR] Not signed into Kong 1Password account."
  echo "Please ensure that your 1Password CLI is signed into Kong's 1Password account."
  echo
  echo "The easiest way to achieve this is to follow the official documentation."
  echo
  echo "See: https://developer.1password.com/docs/cli/app-integration/"
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi

DETAILS=$(
  # shellcheck disable=SC2086
  op $OP_GET_CMD \
    $OP_UUID \
    --fields label=reg_code \
    --format json |
    jq -r '.value' ||
    true
)

if [ -n "$DETAILS" ]; then
  echo
  echo "[INFO] got 1Password item!"
else

  # Get the gateway license
  echo "Get license file from 1Password..."
  DETAILS=$(
    # shellcheck disable=SC2086
    op $OP_GET_CMD \
      $OP_UUID \
      --fields label=reg_code \
      --format json |
      jq -r '.value'
  )
fi

echo "Downloading license..."
NEW_KEY=$(printf "%s" "$DETAILS")
if [[ ! $NEW_KEY == *"signature"* || ! $NEW_KEY == *"payload"* ]]; then
  echo "[ERROR] failed to download the Kong Enterprise license file
    $NEW_KEY"
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi

# validate it is different
OLD_SIG=$(jq -r '.license.signature' <<<"$KONG_LICENSE_DATA")
NEW_SIG=$(jq -r '.license.signature' <<<"$NEW_KEY")

if [[ "$OLD_SIG" == "$NEW_SIG" ]]; then
  echo "[ERROR] The new license is the same as the old one, seems the 1Password license item has not updated yet."
  cleanup
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi

echo "$NEW_KEY" >"$FILENAME"
echo license updated!

# set the license data
export KONG_LICENSE_DATA=$(<"$FILENAME")
PRODUCT=$(jq -r '.license.payload.product_subscription' <<<"$KONG_LICENSE_DATA")
COMPANY=$(jq -r '.license.payload.customer' <<<"$KONG_LICENSE_DATA")
EXPIRE=$(jq -r '.license.payload.license_expiration_date' <<<"$KONG_LICENSE_DATA")
echo "$PRODUCT licensed to $COMPANY, license expires: $EXPIRE"
cleanup
