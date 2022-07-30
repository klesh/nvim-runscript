#!/bin/sh

# OAUTH device mode

set -e

# process arguments
LOGIN_URL=$1
TOKEN_URL=$2
CLIENT_ID=$3
GRANT_TYPE=$4

# verify arguments
if [ -z "$LOGIN_URL" ] || [ -z "$CLIENT_ID" ]; then
    echo "Usage: $0 <login_url> <token_url> <client_id> <grant_type>" >&2
    exit 1
fi

# generate variables
FILENAME=$(echo $LOGIN_URL | grep -oP 'https://\K(.*?)(?=/)')
LOGIN_JSON_PATH=/tmp/$FILENAME.login.json
TOKEN_JSON_PATH=/tmp/$FILENAME.token.json
OPEN=xdg-open
# mac os
if command -v open; then
    OPEN=open
# wsl?
elif command -v start; then
    OPEN=start
fi
BROWSER=${BROWSER-$OPEN}
# echo "LOGIN_URL: $LOGIN_URL"
# echo "TOKEN_URL: $TOKEN_URL"
# echo "CLIENT_ID: $CLIENT_ID"
# echo "GRANT_TYPE: $GRANT_TYPE"
# echo "FILENAME: $FILENAME"
# echo "LOGIN_JSON_PATH: $LOGIN_JSON_PATH"
# echo "TOKEN_JSON_PATH: $TOKEN_JSON_PATH"
# echo "BROWSER: $BROWSER"

fetch_login_json() {
    curl -s "$LOGIN_URL" \
        -H "content-type: application/json" \
        -H "accept: application/json" \
        --data @- <<JSON > $LOGIN_JSON_PATH && echo OAUTH: fetch login json successfully >&2
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

prompt_user_code() {
    USER_CODE=$(jq -r '.user_code' "$LOGIN_JSON_PATH")
    VERIFICATION_URI="$(jq -r '.verification_uri' "$LOGIN_JSON_PATH")"
    echo "OAuth: Please enter the following code on the popping up page:" >&2
    echo "OAuth:   $USER_CODE" >&2
    echo "OAuth: " >&2
    echo "OAuth: If the page wasn't popped up, enter the following URL manually in your browser:" >&2
    echo "OAuth:   $VERIFICATION_URI" >&2
    echo "OAuth: " >&2
    echo "OAuth: This script will wait 20 seconds and then try to fetch the AccessToken every 10 seconds, be patient" >&2
    sleep 3
    "$BROWSER" "$VERIFICATION_URI" >&2
    sleep 17
}

fetch_access_token() {
    DEVICE_CODE="$(jq -r '.device_code' "$LOGIN_JSON_PATH" 2>/dev/null)"
    echo "OAUTH: try to fetch access token" >&2
    curl -s "$TOKEN_URL" \
        -H "content-type: application/json" \
        -H "accept: application/json" \
        --data @- <<JSON > $TOKEN_JSON_PATH
                {
                    "client_id": "$CLIENT_ID",
                    "device_code": "$DEVICE_CODE",
                    "grant_type": "$GRANT_TYPE"
                }
JSON
    # {
    #   "access_token": "gho_16C7e42F292c6912E7710c838347Ae178B4a",
    #   "token_type": "bearer",
    #   "scope": "repo,gist"
    # }
    TOKEN=$(jq -r '.access_token' "$TOKEN_JSON_PATH" 2>/dev/null)
    [ -n "$TOKEN" ] && ! [ "$TOKEN" = "null" ] && echo OAUTH: access token fetched successfully >&2
}

is_login_json_valid() {
    if [ -f "$LOGIN_JSON_PATH" ]; then
        EXPIRED_IN=$(jq -r '.expires_in' "$LOGIN_JSON_PATH" 2>/dev/null)
        if [ "$EXPIRED_IN" -gt 0 ]; then
            LOGIN_TS=$(date -r "$LOGIN_JSON_PATH" "+%s")
            EXPIRED_TS=$(echo "$LOGIN_TS+$EXPIRED_IN-120" | bc)
            NOW_TS=$(date "+%s")
            if [ "$NOW_TS" -lt "$EXPIRED_TS" ]; then
                # if [ -f "$TOKEN_JSON_PATH" ]; then
                #     TOKEN_TS=$(date -r "$TOKEN_JSON_PATH" "+%s")
                #     if [ "$TOKEN_TS" -lt "$LOGIN_TS" ]; then
                #         rm "$TOKEN_JSON_PATH"
                #     fi
                # elif grep -qF "error" "$TOKEN_JSON_PATH"; then
                #     rm "$LOGIN_JSON_PATH"
                #     return 1
                # fi
                return 0
            fi
        fi
    fi
    return 1
}


# fetch_access_token
# load_access_token
TIMEOUT=$(echo $(date '+%s')+90 | bc)
while [ "$(date '+%s')" -lt "$TIMEOUT" ]; do
    if ! is_login_json_valid ;then
        fetch_login_json
        prompt_user_code
    fi
    if fetch_access_token; then
        break
    else
        sleep 10
    fi
done
echo "$TOKEN"
