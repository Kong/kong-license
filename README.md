# Kong Inc internal test license script

This script will pull the internal Kong test license from 1Password and
store it locally. It will also set the environment variable
`KONG_LICENSE_DATA`.

## Usecase

The intent is to store a single company wide test license, short lived, in
1password. And make it easy for everyone to update the local license they use,
whilst being able to do rotation of the license on a regular basis

## Usage:

```
Utility to automatically set the Kong Enterprise license
environment variable 'KONG_LICENSE_DATA' from 1Password.

Usage:
    kong-license/license [--help | --no-update | --update | --clean]

    --update    : force update a non-expired license
    --no-update : do not automatically try to update an expired license
    --clean     : remove locally cached license file
    --help      : display this help information

For convenience you can add the following to your bash profile:
    source kong-license/license --no-update
```

When running the script, it will start printing a warning 10 days before the
license expires.

## Important:

If you want to use the exported `KONG_LICENSE_DATA` environment variable,
then you cannot just run the script, but MUST use `source` to execute it.

```
source kong-license/license
```

It is probably best to add the following line to your bash profile:

```
source kong-license/license --no-update
```


## Requirements:

There are a number of dependencies:

- the 1Password [CLI tools to be installed](https://support.1password.com/command-line-getting-started/)
- [jq](https://stedolan.github.io/jq/) to parse json files


