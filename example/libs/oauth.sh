#!/bin/sh

# OAUTH device mode

set -e

OAUTH_JSON_PATH=/tmp/github_oauth_device.json
OAUTH_TOKEN_JSON_PATH=/tmp/github
OPEN=xdg-open
# mac os
if command -v open; then
    OPEN=open
# wsl?
elif command -v start; then
    OPEN=start
fi
BROWSER=${BROWSER-$OPEN}


get_verification_code() {
    LOGIN_URI=$1
    CLIENT_ID=$2
    FILE_PATH=$3
    if [ -f "$FILE_PATH" ]; then
        EXPIRED_IN=$(jq -r '.expires_in' "$FILE_PATH")
        if [ "$EXPIRED_IN" -gt 0 ]; then
            FILE_MOD_TS=$(date -r "$FILE_PATH" "+%s")
            EXPIRED_TS=$(echo "$FILE_MOD_TS+$EXPIRED_IN" | bc)
            NOW_TS=$(date "+%s")
            if [ "$NOW_TS" -lt "$EXPIRED_TS" ]; then
                return
            fi
        fi
    fi
    curl -sv "$OAUTH_URI" \
        -H "content-type: application/json" \
        -H "accept: application/json" \
        --data @- <<JSON | tee $LOGIN_JSON_PATH
        {
            "client_id": "$CLIENT_ID"
        }
JSON
    # Step 1: App requests the device and user verification codes from GitHub
    # response
    # {
    #   "device_code": "3584d83530557fdd1f46af8289938c8ef79f9dc5",
    #   "user_code": "WDJB-MJHT",
    #   "verification_uri": "https://github.com/login/device",
    #   "expires_in": 900,
    #   "interval": 5
    # }
}

get_access_token() {
    OAUTH_TOKEN_URI=$1
    CLIENT_ID=$2
    LOGIN_JSON_PATH=$3
    TOKEN_JSON_PATH=$4

    if [ -f "$TOKEN_JSON_PATH" ]; then
        TOKEN=$(jq -r '.access_token' "$TOKEN_JSON_PATH" || true)
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            echo "$TOKEN"
            return
        fi
    fi

    USER_CODE=$(jq -r '.user_code' "$LOGIN_JSON_PATH")
    VERIFICATION_URI="$(jq -r '.verification_uri' "$LOGIN_JSON_PATH")"
    DEVICE_CODE="$(jq -r '.device_code' "$LOGIN_JSON_PATH")"
    echo "Please enter the following code on the popping up page:"
    echo "  $USER_CODE"
    echo ""
    echo "If the page wasn't popped up, enter the following URL manually in your browser:"
    echo "  $VERIFICATION_URI"
    sleep 3
    "$BROWSER" "$VERIFICATION_URI"
    TOKEN=
    while [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; do
        curl -sv "$OAUTH_TOKEN_URI" \
            -H "content-type: application/json" \
            -H "accept: application/json" \
            --data @- <<JSON 2>/dev/null | tee $TOKEN_JSON_PATH || true
                    {
                        "client_id": "$CLIENT_ID",
                        "device_code": "$DEVICE_CODE",
                        "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
                    }
JSON
        # {
        #   "access_token": "gho_16C7e42F292c6912E7710c838347Ae178B4a",
        #   "token_type": "bearer",
        #   "scope": "repo,gist"
        # }
        TOKEN=$(jq -r '.access_token' "$TOKEN_JSON_PATH" || true)
        sleep 10
    done
    echo "$TOKEN"
}


get_oauth_token() {
    OAUTH_URI=$1
    OAUTH_TOKEN_URI=$2
    CLIENT_ID=$3
    FILENAME=$(echo $OAUTH_URI | grep -oP 'https://\K(.*?)(?=/)')
    LOGIN_JSON_PATH=/tmp/$FILENAME.login.json
    TOKEN_JSON_PATH=/tmp/$FILENAME.token.json
    if [ -z "$OAUTH_URI" ] || [ -z "$CLIENT_ID" ]; then
        echo "get_oauth_token: invalid arguments, expecting <oauth_uri> <client_id>" >&2
        exit 1
    fi

    get_verification_code "$OAUTH_URI" "$CLIENT_ID" "$LOGIN_JSON_PATH"
    get_access_token "$OAUTH_TOKEN_URI" "$CLIENT_ID" "$LOGIN_JSON_PATH" "$TOKEN_JSON_PATH"
}

