#!/bin/sh


. "$(dirname $0)/../vars/current.sh"

# request github api and format the output with jq
curl -sv "$GITHUB_ENDPOINT/repos/klesh/nvim-runscript" | jq
