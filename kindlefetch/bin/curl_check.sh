#!/bin/sh

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

CURL_BIN="$SCRIPT_DIR/curl/curl-armhf"
CURL_DIR="$SCRIPT_DIR/curl"
CONFIG="$SCRIPT_DIR/curl_config"

[ -f "$CONFIG" ] && . "$CONFIG"

if [ -z "$CURL_DOWNLOAD_URL" ]; then
    echo "Error: CURL_DOWNLOAD_URL not set"
    exit 1
fi

if [ ! -f "$CURL_BIN" ]; then
    echo "curl-armhf not found. Downloading..."
    mkdir -p "$CURL_DIR"
    
    if curl -k -L -o "$CURL_BIN" "$CURL_DOWNLOAD_URL"; then
        chmod +x "$CURL_BIN"
        sync
        echo "Download successful."
    else
        echo "Error: Download failed"
        exit 1
    fi
else
    chmod +x "$CURL_BIN"
    echo "curl-armhf already exists."
fi
