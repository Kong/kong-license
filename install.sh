#!/usr/bin/env bash


# location where to store our files
LOCATION=~/.kong-license-data

# detect profile
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  # unix variant
  PROFILE_SCRIPT=~/.bashrc
else
  # assuming Mac
  PROFILE_SCRIPT=~/.bash_profile
fi

op --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "The 1Password CLI utility 'op' was not found"
  echo "Please download and do the initial signin"
  echo
  echo "See: https://support.1password.com/command-line-getting-started/"
  echo
  [[ $0 != $BASH_SOURCE ]] && return 0 || exit 0
fi

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Utility 'jq' was not found, please make sure it is installed"
  echo "and available in the system path."
  echo
  echo "See: https://stedolan.github.io/jq/"
  echo
  [[ $0 != $BASH_SOURCE ]] && return 0 || exit 0
fi


echo "This installer will set up the Kong license updater"
echo
echo "It will make 2 modifications:"
echo " 1 - install the license script in: $LOCATION"
echo " 2 - add the license script to your $PROFILE_SCRIPT"
echo 
read -p "Continue installing? (y/n)" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then

  echo
  # create directory if it doesn't exist
  if [ ! -d "$LOCATION" ]; then
    echo "creating $LOCATION"
    mkdir "$LOCATION"

    EXEC_COMMAND="source $LOCATION/license --no-update"
    echo "updating: $PROFILE_SCRIPT"
    echo "    with: $EXEC_COMMAND"
    echo ""                           >> "$PROFILE_SCRIPT"
    echo "# Kong license updater"     >> "$PROFILE_SCRIPT"
    echo "$EXEC_COMMAND"              >> "$PROFILE_SCRIPT"

  else
    # location already existed, do not update profile
    echo "$LOCATION already exists, not updating $PROFILE_SCRIPT"
  fi

  echo "copying license script to $LOCATION"
  cp $(dirname "$0")/license $LOCATION/license
  echo "Done. Now executing..."
  echo
  source "$LOCATION/license" --no-update

else
  echo "Aborted"
fi

