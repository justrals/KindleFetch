#!/bin/sh

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/.kindlefetch_config"
VERSION_FILE="$SCRIPT_DIR/.version"

KINDLE_DOCUMENTS="/mnt/us/documents"

UPDATE_AVAILABLE=false

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    exit 1
fi

sanitize_filename() {
    echo "$1" | sed -e 's/[^[:alnum:]\._-]/_/g' -e 's/ /_/g'
}

get_json_value() {
    echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | sed "s/\"$2\":\"\([^\"]*\)\"/\1/" || \
    echo "$1" | grep -o "\"$2\":[^,}]*" | sed "s/\"$2\":\([^,}]*\)/\1/"
}

ensure_config_dir() {
    config_dir=$(dirname "$CONFIG_FILE")
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
}

cleanup() {
    rm -f /tmp/kindle_books.list \
          /tmp/kindle_folders.list \
          /tmp/search_results.json \
          /tmp/last_search_*
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        first_time_setup
    fi
}

get_version() {
    api_response=$(curl -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/justrals/KindleFetch/commits") || {
        echo "Warning: Failed to fetch version from GitHub API" >&2
        echo "unknown"
        return
    }

    latest_sha=$(echo "$api_response" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)
    
    echo "$latest_sha" > "$VERSION_FILE"
}

load_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "Version file wasn't found!"
        sleep 2
        echo "Сreating version file"
        sleep 2
        get_version
    fi
}

check_for_updates() {
    local current_sha=$(load_version)
    
    local latest_sha=$(curl -s -H "Accept: application/vnd.github.v3+json" \
        -H "Cache-Control: no-cache" \
        "https://api.github.com/repos/justrals/KindleFetch/commits?per_page=1" | \
        grep -oE '"sha": "[0-9a-f]+"' | head -1 | cut -d'"' -f4 | cut -c1-7)
    
    if [ -n "$latest_sha" ] && [ "$current_sha" != "$latest_sha" ]; then
        UPDATE_AVAILABLE=true
        return 0
    else
        return 1
    fi
}

save_config() {
    echo "KINDLE_DOCUMENTS=\"$KINDLE_DOCUMENTS\"" > "$CONFIG_FILE"
}

# First time configuration
first_time_setup() {
    clear
    echo -e "
  _____      _               
 / ____|    | |              
| (___   ___| |_ _   _ _ __  
 \___ \ / _ \ __| | | | '_ \ 
 ____) |  __/ |_| |_| | |_) |
|_____/ \___|\__|\__,_| .__/ 
                      | |    
                      |_|    
"
    echo "Welcome to KindleFetch! Let's set up your configuration."
    echo ""
    
    echo -n "Enter your Kindle documents directory [default: $KINDLE_DOCUMENTS]: "
    read user_input
    if [ -n "$user_input" ]; then
        KINDLE_DOCUMENTS="$user_input"
    fi
    
    save_config
}

# Settings menu
settings_menu() {
    while true; do
        clear
        echo -e "
  _____      _   _   _                 
 / ____|    | | | | (_)                
| (___   ___| |_| |_ _ _ __   __ _ ___ 
 \___ \ / _ \ __| __| | '_ \ / _\` / __|
 ____) |  __/ |_| |_| | | | | (_| \__ \\
|_____/ \___|\__|\__|_|_| |_|\__, |___/
                              __/ |    
                             |___/     
"
        echo "Current configuration:"
        echo "1. Documents directory: $KINDLE_DOCUMENTS"
        echo "2. Check for updates"
        echo "3. Back to main menu"
        echo ""
        echo -n "Choose option: "
        read choice
        
        case "$choice" in
            1)
                echo -n "Enter new documents directory: "
                read new_dir
                if [ -n "$new_dir" ]; then
                    KINDLE_DOCUMENTS="$new_dir"
                    save_config
                fi
                ;;
            2)  
                check_for_updates
                if [ "$UPDATE_AVAILABLE" = true ]; then
                    echo "Update is available! Would you like to update? [y/N]: "
                    read confirm

                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        echo "Installing update..."
                        if curl -s https://justrals.github.io/KindleFetch/install/install_kindle.sh | sh; then
                            echo "Update installed successfully!"
                            UPDATE_AVAILABLE=false
                            VERSION=$(load_version)
                            sleep 2
                        else
                            echo "Failed to install update"
                            sleep 2
                        fi
                    fi
                else
                    echo "You're up-to-date!"
                    sleep 2
                fi
                ;;
            3)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Search menu
display_books() {
    clear
    echo -e "
  _____                     _     
 / ____|                   | |    
| (___   ___  __ _ _ __ ___| |__  
 \___ \ / _ \/ _\` | '__/ __| '_ \\ 
 ____) |  __/ (_| | | | (__| | | |
|_____/ \___|\__,_|_|  \___|_| |_|
"
    echo "--------------------------------"
    echo ""
    
    count=$(echo "$1" | grep -o '"title":' | wc -l)
    i=0
    while [ $i -lt $count ]; do
        book_info=$(echo "$1" | awk -v i=$i 'BEGIN{RS="\\{"; FS="\\}"} NR==i+2{print $1}')
        title=$(get_json_value "$book_info" "title")
        author=$(get_json_value "$book_info" "author")
        format=$(get_json_value "$book_info" "format")
        
        printf "%2d. %s\n" $((i+1)) "$title"
        [ -n "$author" ] && echo "    by $author"
        [ -n "$format" ] && echo "    Format: $format"
        
        i=$((i+1))
    done
    
    echo ""
    echo "--------------------------------"
    echo ""
    echo "Page $2 of $5"
    echo ""
    
    if [ "$3" = "true" ]; then
        echo -n "p: Previous page | "
    fi
    if [ "$4" = "true" ]; then
        echo -n "n: Next page | "
    fi
    echo "1-$count: Select book | q: Quit"
    echo ""
}

# Local books menu
list_local_books() {
    local current_dir="${1:-$KINDLE_DOCUMENTS}"
    clear
    echo -e "
 ____              _        
|  _ \            | |       
| |_) | ___   ___ | | _____ 
|  _ < / _ \ / _ \| |/ / __|
| |_) | (_) | (_) |   <\__ \\
|____/ \___/ \___/|_|\_\___/
"
    echo "Current directory: $current_dir"
    echo "--------------------------------"
    echo ""
    
    i=1
    > /tmp/kindle_books.list
    > /tmp/kindle_folders.list

    if [ ! -d "$current_dir" ]; then
        echo "Error: Directory '$current_dir' does not exist."
        return 1
    fi

    for item in "$current_dir"/*; do
        if [ -d "$item" ]; then
            foldername=$(basename "$item")
            echo "$i. $foldername/"
            echo "$item" >> /tmp/kindle_folders.list
            i=$((i+1))
        fi
    done

    for item in "$current_dir"/*; do
        if [ -f "$item" ]; then
            filename=$(basename "$item")
            extension="${filename##*.}"
            echo "$i. $filename"
            echo "$item" >> /tmp/kindle_books.list
            i=$((i+1))
        fi
    done
    
    if [ $i -eq 1 ]; then
        echo "No books or folders found."
        return 1
    fi
    
    echo ""
    echo "--------------------------------"
    echo "n: Go up to parent directory"
    echo "d: Delete directory"
    echo "q: Back to main menu"
    echo ""
}

delete_book() {
    index=$1
    book_file=$(sed -n "${index}p" /tmp/kindle_books.list 2>/dev/null)
    
    if [ -z "$book_file" ]; then
        echo "Invalid selection"
        return 1
    fi

    echo -n "Are you sure you want to delete '$book_file'? [y/N] "
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if rm -f "$book_file"; then
            echo "Book deleted successfully"
        else
            echo "Failed to delete book"
        fi
    else
        echo "Deletion canceled"
    fi
}

delete_directory() {
    index=$1
    dir_path=$(sed -n "${index}p" /tmp/kindle_folders.list 2>/dev/null)
    
    if [ -z "$dir_path" ]; then
        echo "Invalid selection"
        return 1
    fi

    echo -n "Are you sure you want to delete '$dir_path' and all its contents? [y/N] "
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if rm -rf "$dir_path"; then
            echo "Directory deleted successfully"
        else
            echo "Failed to delete directory"
        fi
    else
        echo "Deletion canceled"
    fi
}

search_books() {
    local query="$1"
    local page="${2:-1}"
    
    if [ -z "$query" ]; then
        echo -n "Enter search query: "
        read query
        [ -z "$query" ] && {
            echo "Search query cannot be empty"
            return 1
        }
    fi
    
    echo "Searching for '$query' (page $page)..."
    
    encoded_query=$(echo "$query" | sed 's/ /+/g')
    search_url="https://annas-archive.org/search?q=${encoded_query}&page=${page}"
    
    local html_content=$(curl -s -H "User-Agent: Mozilla/5.0" "$search_url")
    
    local last_page=$(echo "$html_content" | grep -o 'page=[0-9]\+"' | sort -nr | head -1 | cut -d= -f2 | tr -d '"')
    [ -z "$last_page" ] && last_page=1
    
    local has_prev="false"
    [ "$page" -gt 1 ] && has_prev="true"
    
    local has_next="false"
    [ "$page" -lt "$last_page" ] && has_next="true"

    echo "$query" > /tmp/last_search_query
    echo "$page" > /tmp/last_search_page
    echo "$last_page" > /tmp/last_search_last_page
    echo "$has_next" > /tmp/last_search_has_next
    echo "$has_prev" > /tmp/last_search_has_prev
    
    local books=$(echo "$html_content" | awk '
        BEGIN {
            RS="<div class=\"h-\\[110px\\] flex flex-col justify-center \">";
            FS=">";
            print "["
            book_count = 0
        }
        NR > 1 {
            link = ""; md5 = ""; title = ""; author = ""; format = "null"
            
            if ($0 ~ /<a href="\/md5\//) {
                link_start = index($0, "/md5/")
                link_end = index(substr($0, link_start), "\"")
                if (link_end > 0) {
                    link = substr($0, link_start, link_end - 1)
                    md5 = substr(link, 6, 32)
                }
            }
            
            if ($0 ~ /<h3 class=/) {
                title_start = index($0, "<h3")
                title_part = substr($0, title_start)
                title_start = index(title_part, ">") + 1
                title_end = index(title_part, "</h3>")
                if (title_end > 0) {
                    title = substr(title_part, title_start, title_end - title_start)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", title)
                    gsub(/"/, "\\\"", title)
                    gsub(/•/, "\\u2022", title)
                }
            }
            
            if ($0 ~ /<div class=.*italic/) {
                author_start = index($0, "italic")
                author_part = substr($0, author_start)
                author_start = index(author_part, ">") + 1
                author_end = index(author_part, "</div>")
                if (author_end > 0) {
                    author = substr(author_part, author_start, author_end - author_start)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", author)
                    gsub(/"/, "\\\"", author)
                }
            }
            
            if ($0 ~ /text-gray-500">/) {
                format_start = index($0, "text-gray-500\">") + 15
                format_part = substr($0, format_start)
                format_end = index(format_part, "<")
                if (format_end > 0) {
                    format_line = substr(format_part, 1, format_end - 1)
                    if (match(format_line, /\.([a-z0-9]+),/)) {
                        format = substr(format_line, RSTART + 1, RLENGTH - 2)
                        format = "\"" format "\""
                    }
                }
            }
            
            if (title != "") {
                if (book_count > 0) printf ",\n"
                printf "  {\"author\":\"%s\",\"format\":%s,\"md5\":\"%s\",\"title\":\"%s\",\"url\":\"https://annas-archive.org%s\"}", 
                    author, format, md5, title, link
                book_count++
            }
        }
        END { print "\n]" }
    ')
    
    echo "$books" > /tmp/search_results.json
    display_books "$books" "$page" "$has_prev" "$has_next" "$last_page"
}

download_book() {
    index=$1
    
    if [ ! -f "/tmp/search_results.json" ]; then
        echo "Error: No search results found" >&2
        return 1
    fi
    
    book_info=$(awk -v i="$index" 'BEGIN{RS="\\{"; FS="\\}"} NR==i+1{print $1}' /tmp/search_results.json)
    [ -z "$book_info" ] && {
        echo "Invalid selection" >&2
        return 1
    }
    
    md5=$(get_json_value "$book_info" "md5")
    title=$(get_json_value "$book_info" "title")
    author=$(get_json_value "$book_info" "author")
    format=$(get_json_value "$book_info" "format")
    
    echo "Downloading: $title"
    
    clean_title=$(sanitize_filename "$title")
    book_folder="$KINDLE_DOCUMENTS/$clean_title"
    mkdir -p "$book_folder" || {
        echo "Error: Failed to create folder '$book_folder'" >&2
        return 1
    }

    libgen_content=$(curl -s -H "User-Agent: Mozilla/5.0" "https://libgen.li/ads.php?md5=$md5") || {
        echo "Error: Failed to fetch Libgen page" >&2
        return 1
    }
    
    download_link=$(echo "$libgen_content" | grep -o -m 1 'href="[^"]*get\.php[^"]*"' | cut -d'"' -f2)
    [ -z "$download_link" ] && {
        echo "Error: No download link found" >&2
        return 1
    }

    temp_file="$book_folder/temp_$md5"
    echo "Progress:"
    
    for retry in {1..3}; do
        if curl -f -L -C - \
                -o "$temp_file" \
                -H "User-Agent: Mozilla/5.0" \
                -H "Referer: https://libgen.li/" \
                --progress-bar \
                "https://libgen.li/$download_link"; then
            echo -e "\nDownload completed successfully!"
            break
        else
            if [ $retry -eq 3 ]; then
                echo -e "\nError: Download failed after 3 attempts" >&2
                rm -f "$temp_file"
                return 1
            fi
            echo "Retrying ($retry/3)..."
            sleep 2
        fi
    done

    if head -c 4 "$temp_file" | grep -q "%PDF"; then
        extension="pdf"
    elif head -c 4 "$temp_file" | grep -q "EPUB"; then
        extension="epub"
    elif head -c 4 "$temp_file" | grep -q "MOBI"; then
        extension="mobi"
    elif head -c 4 "$temp_file" | grep -q "AZW"; then
        extension="azw3"
    else
        extension="${format:-bin}"
    fi

    final_file="$book_folder/$clean_title.$extension"
    
    if [ -f "$final_file" ]; then
        counter=1
        while [ -f "$book_folder/$clean_title-$counter.$extension" ]; do
            counter=$((counter + 1))
        done
        final_file="$book_folder/$clean_title-$counter.$extension"
    fi

    mv "$temp_file" "$final_file" || {
        echo "Error moving file" >&2
        return 1
    }

    echo "Saved to: $final_file"
    return 0
}

# Main menu
main_menu() {
    load_config
    check_for_updates
    
    while true; do
        clear
        echo -e "
 _  ___           _ _      ______   _       _     
| |/ (_)         | | |    |  ____| | |     | |    
| ' / _ _ __   __| | | ___| |__ ___| |_ ___| |__  
|  < | | '_ \ / _\` | |/ _ \  __/ _ \ __/ __| '_ \\ 
| . \| | | | | (_| | |  __/ | |  __/ || (__| | | |
|_|\_\_|_| |_|\__,_|_|\___|_|  \___|\__\___|_| |_|
                                                
$(load_version) | https://github.com/justrals/KindleFetch                                               
"
        if $UPDATE_AVAILABLE; then
            echo "Update available! Select option 5 to install."
            echo ""
        fi
        echo "1. Search and download books"
        echo "2. List my books"
        echo "3. Settings"
        echo "4. Exit"
        if $UPDATE_AVAILABLE; then
            echo "5. Install update"
        fi
        echo ""
        echo -n "Choose option: "
        read choice
        
        case "$choice" in
            1)
                if search_books; then
                    while true; do
                        query=$(cat /tmp/last_search_query 2>/dev/null)
                        current_page=$(cat /tmp/last_search_page 2>/dev/null || echo 1)
                        last_page=$(cat /tmp/last_search_last_page 2>/dev/null || echo 1)
                        has_next=$(cat /tmp/last_search_has_next 2>/dev/null || echo "false")
                        has_prev=$(cat /tmp/last_search_has_prev 2>/dev/null || echo "false")
                        books=$(cat /tmp/search_results.json 2>/dev/null)
                        count=$(echo "$books" | grep -o '"title":' | wc -l)
                        
                        display_books "$books" "$current_page" "$has_prev" "$has_next" "$last_page"
                        
                        echo -n "Enter choice: "
                        read choice
                        
                        case "$choice" in
                            [qQ])
                                break
                                ;;
                            [pP])
                                if [ "$has_prev" = "true" ]; then
                                    new_page=$((current_page - 1))
                                    search_books "$query" "$new_page"
                                else
                                    echo "Already on first page"
                                    sleep 2
                                fi
                                ;;
                            [nN])
                                if [ "$has_next" = "true" ]; then
                                    new_page=$((current_page + 1))
                                    search_books "$query" "$new_page"
                                else
                                    echo "Already on last page"
                                    sleep 2
                                fi
                                ;;
                            *)
                                if echo "$choice" | grep -qE '^[0-9]+$'; then
                                    if [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                                        download_book "$choice"
                                        echo -n "Press any key to continue..."
                                        read -n 1 -s
                                    else
                                        echo "Invalid selection (must be between 1 and $count)"
                                        sleep 2
                                    fi
                                else
                                    echo "Invalid input"
                                    sleep 2
                                fi
                                ;;
                        esac
                    done
                fi
                ;;
            2)
                current_dir="$KINDLE_DOCUMENTS"
                while true; do
                    if list_local_books "$current_dir"; then
                        total_items=$(( $(wc -l < /tmp/kindle_folders.list 2>/dev/null) + $(wc -l < /tmp/kindle_books.list 2>/dev/null) ))
                        
                        echo -n "Enter choice: "
                        read choice
                        
                        case "$choice" in
                            [qQ])
                                break
                                ;;
                            [nN])
                                current_dir=$(dirname "$current_dir")
                                ;;
                            [dD])
                                echo -n "Enter directory number to delete: "
                                read dir_num
                                if echo "$dir_num" | grep -qE '^[0-9]+$'; then
                                    if [ "$dir_num" -le $(wc -l < /tmp/kindle_folders.list 2>/dev/null) ]; then
                                        delete_directory "$dir_num"
                                    else
                                        echo "Invalid directory number"
                                        sleep 2
                                    fi
                                fi
                                ;;
                            *)
                                if echo "$choice" | grep -qE '^[0-9]+$'; then
                                    if [ "$choice" -ge 1 ] && [ "$choice" -le "$total_items" ]; then
                                        if [ "$choice" -le $(wc -l < /tmp/kindle_folders.list 2>/dev/null) ]; then
                                            current_dir=$(sed -n "${choice}p" /tmp/kindle_folders.list)
                                        else
                                            file_index=$((choice - $(wc -l < /tmp/kindle_folders.list 2>/dev/null)))
                                            delete_book "$file_index"
                                        fi
                                    else
                                        echo "Invalid selection (must be between 1 and $total_items)"
                                        sleep 2
                                    fi
                                else
                                    echo "Invalid input"
                                    sleep 2
                                fi
                                ;;
                        esac
                    else
                        sleep 2
                        break
                    fi
                done
                ;;
            3)
                settings_menu
                ;;
            4)
                cleanup
                exit 0
                ;;
            5)  
                if $UPDATE_AVAILABLE; then
                    echo "Installing update..."
                    if curl -s https://justrals.github.io/KindleFetch/install/install_kindle.sh | sh; then
                        echo "Update installed successfully!"
                        UPDATE_AVAILABLE=false
                        VERSION=$(load_version)
                        sleep 2
                    else
                        echo "Failed to install update"
                        sleep 2
                    fi
                fi
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Start the application
trap cleanup EXIT
main_menu
