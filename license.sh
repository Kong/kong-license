#!/usr/bin/env bash


# location where to store our files
LOCATION=~/.kong-license-data

# License file name
FILE=license.json

# OnePassword account name
OP_ACCOUNT=team_kong

# License entry uuid, use `op list items | jq` to find the right uuid.
OP_UUID=dkuc26kncfeepcrnr32aybvguy


# Nothing to customize below
FILENAME="$LOCATION/$FILE"


function cleanup_kong_license_vars {
  unset LOCATION FILE OP_ACCOUNT FILENAME
  unset PRODUCT COMPANY EXPIRE
  unset EXPIRE_EPOCH NOW_EPOCH WARN_EPOCH EXPIRE_IN
  unset OP_TOKEN OP_UUID DETAILS
  unset BINTRAY_APIKEY BINTRAY_USERNAME BINTRAY_REPO
  unset NEW_KEY OLD_SIG NEW_SIG
}


if [[ "$1" == "--help" ]]; then
  echo "Utility to automatically set the Kong Enterprise license"
  echo "environment variable 'KONG_LICENSE_DATA' from 1Password."
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
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi


if [[ "$1" == "--clean" ]]; then
  rm "$FILENAME"  > /dev/null 2>&1
  rmdir "$LOCATION"  > /dev/null 2>&1
  echo "Removed cached files"
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi


op --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "The 1Password CLI utility 'op' was not found"
  echo "Please download and do the initial signin"
  echo
  echo "See: https://support.1password.com/command-line-getting-started/"
  echo
  echo "Use --help for info."
  echo
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

jq --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo "Utility 'jq' was not found, please make sure it is installed"
  echo "and available in the system path."
  echo
  echo "See: https://stedolan.github.io/jq/"
  echo
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
fi

# TODO: print a warning if op version is outdated: op --update


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
PRODUCT=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.product_subscription' | sed s/\"//g)
COMPANY=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.customer' | sed s/\"//g)
EXPIRE=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.license_expiration_date' | sed s/\"//g)
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


if (( NOW_EPOCH < EXPIRE_EPOCH )); then
  # license still valid
  if (( WARN_EPOCH > EXPIRE_EPOCH )); then
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
    cleanup_kong_license_vars
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
    cleanup_kong_license_vars
    [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 0 || exit 0
  fi
fi


# sign in to 1Password
echo
echo "Logging into 1Password..."
OP_TOKEN=$(op signin $OP_ACCOUNT --output=raw)
if [[ ! $? == 0 ]]; then
  # an error while logging into 1Password
  echo "[ERROR] Failed to get a 1Password token, license data not updated."
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi


# Get the Bintray credentials
DETAILS=$(op get item $OP_UUID --session="$OP_TOKEN")
if [[ ! $? == 0 ]]; then
  # an error while fetching the Bintray keys
  echo "[ERROR] Failed to get the data from 1Password, license data not updated."
  # sign out again
  op signout --session="$OP_TOKEN"
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi


# sign out again
op signout --session="$OP_TOKEN"


BINTRAY_APIKEY=$(echo "$DETAILS" | jq '.details.fields[]? | select(.designation=="password").value' | sed s/\"//g)
BINTRAY_USERNAME=$(echo "$DETAILS" | jq '.details.fields[]? | select(.designation=="username").value' | sed s/\"//g)
BINTRAY_REPO=$(echo "$DETAILS" | jq '.details.sections[].fields[]? | select(.t=="Package/Repository").v' | sed s/\"//g)


echo "Downloading license..."
NEW_KEY=$(curl -s -L -u"$BINTRAY_USERNAME:$BINTRAY_APIKEY" "https://kong.bintray.com/$BINTRAY_REPO/license.json")
if [[ ! $NEW_KEY == *"signature"* || ! $NEW_KEY == *"payload"* ]]; then
  echo "[ERROR] failed to download the Kong Enterprise license file
    $NEW_KEY"
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi


# validate it is different
OLD_SIG=$(echo "$KONG_LICENSE_DATA" | jq '.license.signature' | sed s/\"//g)
NEW_SIG=$(echo "$NEW_KEY" | jq '.license.signature' | sed s/\"//g)

if [[ "$OLD_SIG" == "$NEW_SIG" ]]; then
  echo "[ERROR] The new license is the same as the old one, seems the Bintray license was not updated yet."
  cleanup_kong_license_vars
  [[ "$0" != "${BASH_SOURCE[0]}" ]] && return 1 || exit 1
fi

echo "$NEW_KEY" > "$FILENAME"
echo license updated!

# set the license data
export KONG_LICENSE_DATA=$(<"$FILENAME")
PRODUCT=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.product_subscription' | sed s/\"//g)
COMPANY=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.customer' | sed s/\"//g)
EXPIRE=$(echo "$KONG_LICENSE_DATA" | jq '.license.payload.license_expiration_date' | sed s/\"//g)
echo "$PRODUCT licensed to $COMPANY, license expires: $EXPIRE"
cleanup_kong_license_vars
