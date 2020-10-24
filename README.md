[![Build Status](https://travis-ci.com/Kong/kong-license.svg?token=oiCtUsXk8yspLqn3VrwK&branch=master)](https://travis-ci.com/Kong/kong-license)

# Kong Inc internal test license script

This script will pull the internal Kong test license from 1Password/Bintray and
store it locally. 

The intent is to store a single company wide test license, short lived, in
1Password/Bintray. And make it easy for everyone to update the local license they use,
whilst being able to do rotation of the license on a regular basis.

It will also set the environment variable `KONG_LICENSE_DATA` whenever you open
up a new terminal, so it is easy to pass to Kong. 10 days before the license
expires it will start printing warnings, accompanied by the proper update
command.

## Installation

1. Install dependencies:
    - Install `jq`, see https://stedolan.github.io/jq/
    - Install 1Password CLI tools, see [1Password CLI](https://support.1password.com/command-line-getting-started/)
2. Make sure you did the initial sign-in, see [1Password instructions](https://support.1password.com/command-line-getting-started/#get-started-with-the-command-line-tool)
3. Clone this git repo
4. Run `make install` from the repo
5. Run `~/.local/bin/license` from the command line, this will initiate the initial update
6. When asked enter your 1Password credentials
7. Done! You now have the latest license data from 1Password/Bintray

## Usage:

```
Utility to automatically set the Kong Enterprise license
environment variable 'KONG_LICENSE_DATA' from 1Password.

Usage:
    ~/.local/bin/license [--help | --no-update | --update | --clean]

    --update    : force update a non-expired license
    --no-update : do not automatically try to update an expired license
    --clean     : remove locally cached license file
    --help      : display this help information

For convenience you can add the following to your bash profile:
    source ~/.local/bin/license --no-update
```

When running the script, it will start printing a warning 10 days before the
license expires.

## Requirements:

There are a number of dependencies:

- the 1Password [CLI tools to be installed](https://support.1password.com/command-line-getting-started/)
- [jq](https://stedolan.github.io/jq/) to parse json files


If you want to use the exported `KONG_LICENSE_DATA` environment variable,
then you cannot just run the script, but MUST use `source` to execute it.

```
source ~/.local/bin/license
```

It is probably best to add the following line to your bash profile:

```
source ~/.local/bin/license --no-update
```
To update the license in bintray, upload the new license.json file to here: https://bintray.com/beta/#/kong/kong/license?tab=files
