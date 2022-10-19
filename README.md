[![Build Status](https://travis-ci.com/Kong/kong-license.svg?token=oiCtUsXk8yspLqn3VrwK&branch=master)](https://travis-ci.com/Kong/kong-license)

# Kong Inc internal test license script

There are 3 scripts/actions;

1. [user script](#user-script)
2. [automation script](#automation-script)
3. [github action](#github-action)

# User script

This script will pull the internal Kong test license from 1Password/Pulp and
store it locally.

The intent is to store a single company wide test license, short lived, in
1Password/Pulp. And make it easy for everyone to update the local license they use,
whilst being able to do rotation of the license on a regular basis.

It will also set the environment variable `KONG_LICENSE_DATA` whenever you open
up a new terminal, so it is easy to pass to Kong. 10 days before the license
expires it will start printing warnings, accompanied by the proper update
command.

---

## 1Password Shared Vault Access

Before continuing, make sure you have access to the "Shared" vault in 1Password. You can request access to this vault via the `#it` Kong slack channel. There is an example request [here](https://kongstrong.slack.com/archives/C5B4SU6KC/p1615993209037400) that can be referenced if it's not clear what is being requested from the IT team.

Note that if you have configured your local 1Password with biometric security (e.g. Apple Face ID), this is not supported by the license script. You will have to add your accounts to the 1Password CLI tool [manually](https://developer.1password.com/docs/cli/sign-in-manually).

---

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

---

## Usage

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

If you want to use the exported `KONG_LICENSE_DATA` environment variable,
then you cannot just run the script, but MUST use `source` to execute it.

```
source ~/.local/bin/license
```

It is probably best to add the following line to your bash/zsh profile:

```
source ~/.local/bin/license --no-update
```

---

# Automation script

The `auto-license.sh` script will download the Kong license file given a Pulp
password, and pass it to `stdout`. The script will take the Pulp password either
via `stdin` or from the environment variable `PULP_PASSWORD`.
The `PULP_USERNAME` environment variable is optional, and will default to
`admin`.

Note that this just exchanges one secret problem (the license) for another (the
Pulp password), but in many cases the latter is already available, and in those
cases this helps prevent having yet another secret.

Example use:
```shell
# assumes PULP_PASSWORD is set
git clone --depth=1 --single-branch https://github.com/Kong/kong-license.git
export KONG_LICENSE_DATA=$(./kong-license/auto-license.sh)

# assumes the Pulp password is stored in THE_PASSWORD
git clone --depth=1 --single-branch https://github.com/Kong/kong-license.git
export KONG_LICENSE_DATA=$(./kong-license/auto-license.sh <<< "$THE_PASSWORD")
```

---

# Github action

The Github action in this repo will fetch a license provided the Pulp credentials
are available. To do this it uses the [Automation script](#automation-script) under
the hood. The action output will be the Kong License. The license will also be
exported as the `KONG_LICENSE_DATA` environment variable for follow up steps.
The license signature will be masked in the log output.

Here's how to use the action:
```yaml
    steps:
    - uses: Kong/kong-license@master
      id: getLicense
      with:
        # The password is required
        password: ${{ secrets.PULP_PASSWORD }}
        # The username defaults to "admin"
        #username: ${{ secrets.PULP_USERNAME }}
```

In any follow up step, requiring the Kong license, it can be added like this:
```yaml
    steps:
    - run: kong start
      shell: bash
      env:
        #KONG_LICENSE_DATA has been set by the license-action
        MY_LICENSE: ${{ steps.getLicense.outputs.license }}
```

The shortest version relying on defaults and environment variables being set:
```yaml
    steps:
    - uses: Kong/kong-license@master
      with:
        password: ${{ secrets.PULP_PASSWORD }}
    - run: kong start
      shell: bash
```

---

# Uploading a license

To update the license in Pulp, the [release_scripts](https://github.com/Kong/release-scripts) Docker image
can be used

```
docker run -e PULP_USERNAME="<username>" \
           -e PULP_PASSWORD="<password>" \
           -e PULP_HOST="https://api.pulp.konnect-prod.konghq.com" \
           -v ${PWD}/license.json:/license.json:ro \
           -it kong/release-script \
           --package-type license \
           --file /license.json
```

**Note**: Credentials for the production Pulp API can be obtained in 1Password shared vault.

---

# Troubleshooting

## Seeing error "isn't an item in any vault"

If you see an error similar to the following:

```
[ERROR] 2021/03/16 08:59:05 "c5jg2oc6wzg6ffs2awxeohrnmm" isn't an item in any vault.
```

This means that you don't have access to the shared vault in 1Password. See [above](#1password-shared-vault-access) for more information on how to get the necessary access.
