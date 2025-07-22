#!/bin/sh

zlib_download() {
    local index=$1
    
    if [ ! -f "$TMP_DIR/search_results.json" ]; then
        echo "Error: No search results found" >&2
        return 1
    fi
    
    local book_info=$(awk -v i="$index" 'BEGIN{RS="\\{"; FS="\\}"} NR==i+1{print $1}' $TMP_DIR/search_results.json)
    if [ -z "$book_info" ]; then
        echo "Error: Invalid book selection" >&2
        return 1
    fi
    
    local md5=$(get_json_value "$book_info" "md5")
    local title=$(get_json_value "$book_info" "title")
    local format=$(get_json_value "$book_info" "format")
    
    echo "Downloading: $title"

    local clean_title=$(sanitize_filename "$title" | tr -d ' ')
    local final_location

    echo -n "Do you want to change filename? [y/N] "
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -n "Enter your custom filename: "
        read custom_filename
        if [ -n "$custom_filename" ]; then
            local clean_title=$(sanitize_filename "$custom_filename" | tr -d ' ')
        else
            echo "Invalid filename. Proceeding with original filename."
        fi
    else
        echo "Proceeding with original filename."
    fi
    
    if [ ! -w "$KINDLE_DOCUMENTS" ]; then
        echo "Error: No write permission in $KINDLE_DOCUMENTS" >&2
        return 1
    fi

    if [ "$CREATE_SUBFOLDERS" = "true" ]; then
        local book_folder="$KINDLE_DOCUMENTS/$clean_title"
        if ! mkdir -p "$book_folder"; then
            echo "Error: Failed to create folder '$book_folder'" >&2
            return 1
        fi
        final_location="$book_folder/$clean_title.$format"
    else
        final_location="$KINDLE_DOCUMENTS/$clean_title.$format"
    fi

    if [ -e "$final_location" ] && [ ! -w "$final_location" ]; then
        echo "Error: No permission to overwrite $final_location" >&2
        return 1
    fi

    echo "Fetching download page..."
    if ! zlib_content=$(curl -s -L "$ZLIB_URL/md5/$md5"); then
        if ! zlib_content=$(curl -s -L -x "$PROXY_URL" "$ZLIB_URL/md5/$md5"); then
            echo "Error: Failed to fetch book page" >&2
            return 1
        fi
    fi
    
    if ! download_link=$(echo "$zlib_content" | grep -o 'href="/dl/[^"]*"' | head -1 | sed 's/href="//;s/"//'); then
        echo "Error: Failed to parse download link" >&2
        return 1
    fi
    
    if [ -z "$download_link" ]; then
        echo "Error: No download link found" >&2
        return 1
    fi

    local download_url="$ZLIB_URL$download_link"
    echo "Downloading from: $download_url"

    echo "Progress:"
    
    for retry in 1 2 3; do
        if curl -# -L -o "$final_location" "$download_url"; then
            echo "Download successful!"
            echo "Saved to: $final_location"
            return 0
        else
            if curl -x "$PROXY_URL" -# -L -o "$final_location" "$download_url"; then
                echo "Download successful!"
                echo "Saved to: $final_location"
                return 0
            else
                echo "Download attempt $retry failed"
                [ $retry -lt 3 ] && sleep 5
            fi
        fi
    done
    
    echo "Error: Failed to download after 3 attempts" >&2
    return 1
}