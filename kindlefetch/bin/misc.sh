#!/bin/sh

change_dns () {
    RESOLV_FILE="/var/run/resolv.conf"
    
    if [ ! -f "$RESOLV_FILE" ]; then
        exit 1
    fi

    sed -i '/^nameserver/d' "$RESOLV_FILE"

    echo "nameserver 1.1.1.1" >> "$RESOLV_FILE"
    echo "nameserver 1.0.0.1" >> "$RESOLV_FILE"
}

load_config() {
    eval "$(base64 -d "$LINK_CONFIG_FILE")"
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        first_time_setup
    fi
}

load_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "Version file wasn't found!"
        sleep 2
        echo "Creating version file"
        sleep 2
        get_version
    fi
}

sanitize_filename() {
    echo "$1" | sed -e 's/[^[:alnum:]\._-]/_/g' -e 's/ /_/g'
}

get_json_value() {
    echo "$1" | grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"/\1/" || \
    echo "$1" | grep -o "\"$2\"[[:space:]]*:[[:space:]]*[^,}]*" | sed "s/\"$2\"[[:space:]]*:[[:space:]]*\([^,}]*\)/\1/"
}

ensure_config_dir() {
    local config_dir="$(dirname "$CONFIG_FILE")"
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
}

cleanup() {
    rm -f "$TMP_DIR"/kindle_books.list \
          "$TMP_DIR"/kindle_folders.list \
          "$TMP_DIR"/search_results.json \
          "$TMP_DIR"/last_search_*
}

get_version() {
    local api_response="$(curl -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/justrals/KindleFetch/commits")" || {
        echo "Warning: Failed to fetch version from GitHub API" >&2
        echo "unknown"
        return
    }

    local latest_sha="$(echo "$api_response" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)"
    
    echo "$latest_sha" > "$VERSION_FILE"
    load_version
}

check_for_updates() {
    local current_sha="$(load_version)"
    
    local latest_sha="$(curl -s -H "Accept: application/vnd.github.v3+json" \
        -H "Cache-Control: no-cache" \
        "https://api.github.com/repos/justrals/KindleFetch/commits?per_page=1" | \
        grep -oE '"sha": "[0-9a-f]+"' | head -1 | cut -d'"' -f4 | cut -c1-7)"
    
    if [ -n "$latest_sha" ] && [ "$current_sha" != "$latest_sha" ]; then
        UPDATE_AVAILABLE=true
        return 0
    else
        return 1
    fi
}

save_config() {
    {
        echo "KINDLE_DOCUMENTS=\"$KINDLE_DOCUMENTS\""
        echo "CREATE_SUBFOLDERS=\"$CREATE_SUBFOLDERS\""
        echo "DEBUG_MODE=\"$DEBUG_MODE\""
        echo "COMPACT_OUTPUT=\"$COMPACT_OUTPUT\""
        echo "ENFORCE_DNS=\"$ENFORCE_DNS\""
        echo "ZLIB_AUTH=\"$ZLIB_AUTH\""
        echo "ZLIB_USERNAME=\"$ZLIB_USERNAME\""
        echo "ANNAS_TLD=\"$ANNAS_TLD\""
    } > "$CONFIG_FILE"
}

zlib_login() {
    local zlib_login="$1"
    local zlib_password="$2"

    printf '\nLogging in to Z-Library...'

    local response="$(curl -s -c "$ZLIB_COOKIES_FILE" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Accept: application/json" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
        -X POST -d "email=$zlib_login&password=$zlib_password" \
        "$ZLIB_URL/eapi/user/login")"

    local zlib_username="$(get_json_value "$response" "name" | tr -d '\r\n')"

    if [ -n "$zlib_username" ]; then
        printf "\nSuccessfully logged in as $zlib_username!"
        ZLIB_USERNAME="$zlib_username"
        sleep 2
    else
        printf "\nLogin failed."
        printf "\n$response" | head -n1
        sleep 2
        return 1
    fi
}