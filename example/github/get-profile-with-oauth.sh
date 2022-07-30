#!/bin/sh

# This example shows you a breif idea of how to do OAuth API testing

# First, create the OAuth app. For Github, check the following guide:
# https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app 
# (Remember to "Enable Device Flow")

# Second, we source all Variables that we need, let the `current.sh` be a symlink is recommended so we may switch
# to a different set of Variables easily.
. "$(dirname $0)/../vars/current.sh"

# Third, source the OAuth functions file, you may copy it to whereever you like and change in anyway you want.
OAUTH_SCRIPT_PATH="$(dirname $0)/../libs/oauth.sh"

# It would be safer to keep your secrets in a GitIgnored file
. "$(dirname $0)/../vars/my.secret.sh"
# GITHUB_OAUTH_CLIENT_ID=

# Finally, utilize the OAuth functions to get your access token. you may need to 
TOKEN=$("$OAUTH_SCRIPT_PATH" \
    "$GITHUB_OAUTH_LOGIN_URI" \
    "$GITHUB_OAUTH_TOKEN_URI" \
    "$GITHUB_OAUTH_CLIENT_ID" \
    "$GITHUB_OAUTH_GRANT_TYPE")
curl -sv "$GITHUB_ENDPOINT/user" \
    -H "Authorization: Bearer $TOKEN"

