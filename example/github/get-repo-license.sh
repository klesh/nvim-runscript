#!/bin/sh

DIR=$(dirname $0)
. "$DIR/../vars/current.sh"

license_url=$($DIR/get-repo-detail.sh "$@" | jq -r '.license.url' )

# request github api and format the output with jq
curl -sv "$license_url" | jq
