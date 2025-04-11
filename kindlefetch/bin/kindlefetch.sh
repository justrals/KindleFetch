#!/bin/sh

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CERT_PATH="$SCRIPT_DIR/cacert.pem"
CONFIG_FILE="$SCRIPT_DIR/.kindlefetch_config"
VERSION_FILE="$SCRIPT_DIR/.version"

KINDLE_DOCUMENTS="/mnt/us/documents"
BOOK_FIRST_SOURCE=""
BOOK_SECOND_SOURCE=""
CREATE_SUBFOLDERS=false
CONDENSED_OUTPUT=false
DEBUG_MODE=false
FILETYPES="pdf,epub,mobi,azw,azw3,txt,doc,docx,rtf"

UPDATE_AVAILABLE=false

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    echo "Press any key to exit."
    read -n 1 -s
    exit 1
fi

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        first_time_setup
    fi
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
    echo "NOTE: This tool does not provide copyrighted material. You must configure your own book sources."
    echo ""
    
    echo -n "Enter your Kindle documents directory [default: $KINDLE_DOCUMENTS]: "
    read user_input
    if [ -n "$user_input" ]; then
        KINDLE_DOCUMENTS="$user_input"
    fi
    echo -n "Enter your first book source link [example: https://link-adress.com]: "
    read user_input
    if [ -n "$user_input" ]; then
        BOOK_FIRST_SOURCE="$user_input"
    fi
    echo -n "Enter your second book source link [example: https://link-adress.com]: "
    read user_input
    if [ -n "$user_input" ]; then
        BOOK_SECOND_SOURCE="$user_input"
    fi
    echo -n "Create subfolders for books? (true/false): "
    read subfolders_choice
    if [ "$subfolders_choice" = "true" ] || [ "$subfolders_choice" = "false" ]; then
        CREATE_SUBFOLDERS="$subfolders_choice"
    else
        CREATE_SUBFOLDERS="false"
    fi
    echo -n "Enable condensed output? (true/false): "
    read condensed_choice
    if [ "$condensed_choice" = "true" ] || [ "$condensed_choice" = "false" ]; then
        CONDENSED_OUTPUT="$condensed_choice"
    else
        CONDENSED_OUTPUT="false"
    fi

    save_config
}

# Check if required websites are accessible
check_websites() {
    echo "Checking connectivity to required websites..."

    if ! curl --insecure -s --head --connect-timeout 5 --max-time 10 $BOOK_FIRST_SOURCE/ >/dev/null; then
        echo "Error: Cannot connect to your first book source ($BOOK_FIRST_SOURCE/)" >&2
        echo "Please check your internet connection or try again later." >&2
        echo "Do you want to change the url? [y/N]: "
        read confirm

        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo -n "Enter new first book source [example: https://link-adress.com]: "
            read user_input
            if [ -n "$user_input" ]; then
                BOOK_FIRST_SOURCE="$user_input"
            fi
            save_config
            check_websites
        else
            exit 1
        fi
    fi
    
    if ! curl --insecure -s --head --connect-timeout 5 --max-time 10 $BOOK_SECOND_SOURCE/ >/dev/null; then
        echo "Error: Cannot connect to your second book source ($BOOK_SECOND_SOURCE/)" >&2
        echo "Please check your internet connection or try again later." >&2
        echo "Do you want to change the url? [y/N]: "
        read confirm

        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo -n "Enter new second book source [example: https://link-adress.com]: "
            read user_input
            if [ -n "$user_input" ]; then
                BOOK_SECOND_SOURCE="$user_input"
            fi
            save_config
            check_websites
        else
            exit 1
        fi
    fi
    
    echo "Website connectivity check: OK"
}

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

get_version() {
    api_response=$(curl --insecure -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/justrals/KindleFetch/commits") || {
        echo "Warning: Failed to fetch version from GitHub API" >&2
        echo "unknown"
        return
    }

    latest_sha=$(echo "$api_response" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)
    
    echo "$latest_sha" > "$VERSION_FILE"
    load_version
}

check_for_updates() {
    local current_sha=$(load_version)
    
    local latest_sha=$(curl --insecure -s -H "Accept: application/vnd.github.v3+json" \
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
    echo "CREATE_SUBFOLDERS=\"$CREATE_SUBFOLDERS\"" >> "$CONFIG_FILE"
    echo "DEBUG_MODE=\"$DEBUG_MODE\"" >> "$CONFIG_FILE"
    echo "CONDENSED_OUTPUT=\"$CONDENSED_OUTPUT\"" >> "$CONFIG_FILE"
    echo "BOOK_FIRST_SOURCE=\"$BOOK_FIRST_SOURCE\"" >> "$CONFIG_FILE"
    echo "BOOK_SECOND_SOURCE=\"$BOOK_SECOND_SOURCE\"" >> "$CONFIG_FILE"
    echo "FILETYPES=\"$FILETYPES\"" >> "$CONFIG_FILE"
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
        echo "Tip:"
        echo "Tap two fingers and press the X button to refresh the screen."
        echo ""
        echo "Current configuration:"
        echo "1. Documents directory: $KINDLE_DOCUMENTS"
        echo "2. Toggle subfolders for books: $CREATE_SUBFOLDERS"
        echo "3. Toggle debug mode: $DEBUG_MODE"
        echo "4. Toggle condensed output: $CONDENSED_OUTPUT"
echo "5. First book source: $BOOK_FIRST_SOURCE"
echo "6. Second book source: $BOOK_SECOND_SOURCE"
echo "7. Configure allowed file types: $FILETYPES"
echo "8. Check for updates"
echo "9. Back to main menu"
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
                if $CREATE_SUBFOLDERS; then
                    CREATE_SUBFOLDERS=false
                    echo "Subfolders disabled"
                else
                    CREATE_SUBFOLDERS=true
                    echo "Subfolders enabled"
                fi
                save_config
                ;;
            3)  
                if $DEBUG_MODE; then
                    DEBUG_MODE=false
                    echo "Debug mode disabled"
                else
                    DEBUG_MODE=true
                    echo "Debug mode enabled"
                fi
                save_config
                ;;
            4)
                if $CONDENSED_OUTPUT; then
                    CONDENSED_OUTPUT=false
                    echo "Condensed output disabled"
                else
                    CONDENSED_OUTPUT=true
                    echo "Condensed output enabled"
                fi
                save_config
                ;;
            5)
                echo -n "Enter new first book source [example: https://link-adress.com]: "
                read user_input
                if [ -n "$user_input" ]; then
                    BOOK_FIRST_SOURCE="$user_input"
                fi
                save_config
                ;;
            6)
                echo -n "Enter new second book source [example: https://link-adress.com]: "
                read user_input
                if [ -n "$user_input" ]; then
                    BOOK_SECOND_SOURCE="$user_input"
                fi
                save_config
                ;;
            7)
                echo "Current allowed file types: $FILETYPES"
                echo -n "Enter new file types (comma-separated, e.g. pdf,epub,mobi): "
                read new_types
                if [ -n "$new_types" ]; then
                    FILETYPES="$new_types"
                    save_config
                    echo "File types updated"
                    sleep 2
                fi
                ;;
            8)
                check_for_updates
                if [ "$UPDATE_AVAILABLE" = true ]; then
                    echo "Update is available! Would you like to update? [y/N]: "
                    read confirm

                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        echo "Installing update..."
                        if curl --insecure -s https://justrals.github.io/KindleFetch/install.sh | sh; then
                            echo "Update installed successfully!"
                            UPDATE_AVAILABLE=false
                            VERSION=$(load_version)
                            exec exit 0
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
            9)
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
    
    # Debug output
    if $DEBUG_MODE; then
        echo "Debug - Raw JSON input:" >&2
        echo "$1" | head -n 5 >&2
        echo "..." >&2
        echo "$1" | tail -n 5 >&2
        
        count=$(echo "$1" | grep -o '"title":' | wc -l)
        echo "Debug - Found $count books" >&2
    fi
    i=0
    while [ $i -lt $count ]; do
        book_info=$(echo "$1" | awk -v i=$i 'BEGIN{RS="\\{"; FS="\\}"} NR==i+2{print $1}')
        title=$(get_json_value "$book_info" "title")
        author=$(get_json_value "$book_info" "author")
        format=$(get_json_value "$book_info" "format")
        
        if ! $CONDENSED_OUTPUT; then
            printf "%2d. %s\n" $((i+1)) "$title"
            [ -n "$author" ] && echo "    by $author"
            [ -n "$format" ] && echo "    Format: $format"
            echo ""
        else
            printf "%2d. %s by %s in %s format\n" $((i+1)) "$title" "$author" "$format"
            echo ""
        fi
        
        
        i=$((i+1))
    done
    
    echo "--------------------------------"
    echo ""
    
    # Check if we have a multi-page result
    if [ -f "/tmp/last_search_pages_fetched" ]; then
        pages_fetched=$(cat /tmp/last_search_pages_fetched 2>/dev/null || echo "$2")
        if [ "$(echo "$pages_fetched" | grep -o ',' | wc -l)" -gt 0 ]; then
            # Format the pages list nicely
            formatted_pages=$(echo "$pages_fetched" | tr ',' ' ' | sed 's/ /, /g')
            echo "Results from pages $formatted_pages"
        else
            echo "Page $2 of $5"
        fi
    else
        echo "Page $2 of $5"
    fi
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
    local min_results=10  # Minimum number of filtered results to show
    local max_pages=5     # Maximum number of pages to fetch for getting filtered results
    local last_page=1
    
    if [ -z "$query" ]; then
        echo -n "Enter search query: "
        read query
        [ -z "$query" ] && {
            echo "Search query cannot be empty"
            return 1
        }
    fi
    
    echo "Searching for '$query'..."
    
    # Store fetched pages in array
    local pages_fetched="$current_page"
    local result_count=0
    local current_page=$page
    local first_page=$page
    local filtered_has_prev=false
    local filtered_has_next=false
    
    # Get first page and determine last page
    encoded_query=$(echo "$query" | sed 's/ /+/g')
    search_url="$BOOK_FIRST_SOURCE/search?index=&page=${current_page}&q=${encoded_query}&display=&src=lgli&sort="
    local html_content=$(curl --insecure -s -H "User-Agent: Mozilla/5.0" "$search_url")
    
    last_page=$(echo "$html_content" | grep -o 'page=[0-9]\+"' | sort -nr | head -1 | cut -d= -f2 | tr -d '"')
    [ -z "$last_page" ] && last_page=1

    local page_results=$(echo "$html_content" | awk -v allowed="$(echo "$FILETYPES" | tr '[:upper:]' '[:lower:]')" -v current_page="$current_page" '
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
            
            # Convert format to lowercase for case-insensitive comparison
            tolower_format = format
            gsub(/"/, "", tolower_format)
            tolower_format = tolower(tolower_format)
            
            # Check if format is in allowed types
            is_allowed = 0
            if (allowed == "*" || allowed == "") {
                is_allowed = 1
            } else {
                split(allowed, allowed_arr, ",")
                for (i in allowed_arr) {
                    if (index(tolower_format, tolower(allowed_arr[i])) > 0) {
                        is_allowed = 1
                        break
                    }
                }
            }
            
            if (title != "" && is_allowed) {
                if (book_count > 0) printf ",\n"
                printf "  {\"author\":\"%s\",\"format\":%s,\"md5\":\"%s\",\"title\":\"%s\",\"url\":\"$BOOK_FIRST_SOURCE%s\"}", 
                    author, format, md5, title, link
                book_count++
            }
        }
        END { print "\n]" }
    ')
    
    local all_results="$page_results"
    result_count=$(echo "$page_results" | grep -o '"title":' | wc -l)
    
    # If we don't have enough results and there are more pages, fetch them
    while [ $result_count -lt $min_results ] && [ $current_page -lt $last_page ] && [ $current_page -lt $((first_page + max_pages)) ]; do
        current_page=$((current_page + 1))
        echo "Fetching additional results from page $current_page..."
        
        search_url="$BOOK_FIRST_SOURCE/search?index=&page=${current_page}&q=${encoded_query}&display=&src=lgli&sort="
        html_content=$(curl --insecure -s -H "User-Agent: Mozilla/5.0" "$search_url")
        
        page_results=$(echo "$html_content" | awk -v allowed="$(echo "$FILETYPES" | tr '[:upper:]' '[:lower:]')" -v current_page="$current_page" '
            BEGIN {
                RS="<div class=\"h-\\[110px\\] flex flex-col justify-center \">";                FS=">";                book_count = 0
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
                
                tolower_format = format
                gsub(/"/, "", tolower_format)
                tolower_format = tolower(tolower_format)
                
                is_allowed = 0
                if (allowed == "*" || allowed == "") {
                    is_allowed = 1
                } else {
                    split(allowed, allowed_arr, ",")
                    for (i in allowed_arr) {
                        if (index(tolower_format, tolower(allowed_arr[i])) > 0) {
                            is_allowed = 1
                            break
                        }
                    }
                }
                
                if (title != "" && is_allowed) {
                    printf "{\"author\":\"%s\",\"format\":%s,\"md5\":\"%s\",\"title\":\"%s\",\"url\":\"%s%s\"}\n",
                        author, format, md5, title, ENVIRON["BOOK_FIRST_SOURCE"], link
                }
            }
        ')
        
        # Only include non-empty results
        if [ -n "$page_results" ]; then
            # Proper JSON merging for multi-page results
            if [ -n "$all_results" ]; then
                # Extract arrays without outer brackets
                local first_array=$(echo "$all_results" | sed 's/^\[//;s/\]$//')
                local second_array=$(echo "$page_results" | sed 's/^\[//;s/\]$//')
                
                # Combine with a comma if both have content
                if [ -n "$first_array" ] && [ -n "$second_array" ]; then
                    all_results="[${first_array},${second_array}]"
                elif [ -n "$first_array" ]; then
                    all_results="[${first_array}]"
                elif [ -n "$second_array" ]; then
                    all_results="[${second_array}]"
                else
                    all_results="[]"
                fi
            else
                all_results="$page_results"
            fi
            
            # Update pages fetched
            pages_fetched="$pages_fetched,$current_page"
        fi
        
        result_count=$(echo "$all_results" | grep -c .)
    done
    
    # Format results as JSON array
    echo "$all_results" > /tmp/search_results.json
    
    # Update pagination status
    filtered_has_prev=false
    [ "$first_page" -gt 1 ] && filtered_has_prev=true
    
    filtered_has_next=false
    [ $current_page -lt $last_page ] && filtered_has_next=true
    
    # Save search state
    echo "$query" > /tmp/last_search_query
    echo "$first_page" > /tmp/last_search_page
    echo "$last_page" > /tmp/last_search_last_page
    echo "$pages_fetched" > /tmp/last_search_pages_fetched
    echo "$filtered_has_next" > /tmp/last_search_has_next
    echo "$filtered_has_prev" > /tmp/last_search_has_prev
    
    display_books "$all_results" "$first_page" "$filtered_has_prev" "$filtered_has_next" "$last_page"
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
    
    clean_title=$(sanitize_filename "$title" | tr -d ' ')
    
    if [ ! -w "$KINDLE_DOCUMENTS" ]; then
        echo "Error: No write permission in $KINDLE_DOCUMENTS" >&2
        return 1
    fi
    
    if [ "$CREATE_SUBFOLDERS" = "true" ]; then
        book_folder="$KINDLE_DOCUMENTS/$clean_title"
        mkdir -p "$book_folder" || {
            echo "Error: Failed to create folder '$book_folder'" >&2
            return 1
        }
        final_location="$book_folder/$clean_title.$format"
    else
        book_folder="$KINDLE_DOCUMENTS"
        final_location="$book_folder/$clean_title.$format"
    fi

    if [ -e "$final_location" ] && [ ! -w "$final_location" ]; then
        echo "Error: No permission to overwrite $final_location" >&2
        return 1
    fi

    second_source_content=$(curl --insecure -s -H "User-Agent: Mozilla/5.0" "$BOOK_SECOND_SOURCE/ads.php?md5=$md5") || {
        echo "Error: Failed to fetch second book source page" >&2
        return 1
    }
    
    download_link=$(echo "$second_source_content" | grep -o -m 1 'href="[^"]*get\.php[^"]*"' | cut -d'"' -f2)
    [ -z "$download_link" ] && {
        echo "Error: No download link found" >&2
        return 1
    }

    temp_file="/tmp/kindlefetch_temp_$md5.$format"

    download_url=$(echo "$download_link" | grep -q '^http' && echo "$download_link" || echo "$BOOK_SECOND_SOURCE/$download_link")

    echo "Progress:"
    
    for retry in 1 2 3; do
        if curl --insecure --tlsv1.2 -f -L \
                -o "$temp_file" \
                -H "User-Agent: Mozilla/5.0" \
                -H "Referer: $BOOK_SECOND_SOURCE/" \
                --progress-bar \
                "$download_url"; then
            echo -e "\nDownload completed successfully!"
            
            if [ ! -w "$book_folder" ]; then
                echo "Error: No write permission in $book_folder" >&2
                rm -f "$temp_file"
                return 1
            fi
            
            if cp "$temp_file" "$final_location" && rm -f "$temp_file"; then
                echo "File saved to: $final_location"
                chmod 644 "$final_location"
                return 0
            else
                echo "Error: Failed to move file (permission denied?)" >&2
                echo "The downloaded file was saved temporarily at: $temp_file" >&2
                return 1
            fi
        else
            echo -e "\nDownload attempt $retry failed"
            [ $retry -lt 3 ] && sleep 5
        fi
    done
    
    echo "Error: Failed to download after 3 attempts" >&2
    return 1
}

# Main menu
main_menu() {
    load_config
    check_for_updates
    check_websites
    
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
                                    # For multi-page results we load more pages
                                    new_page=$((current_page + 1))
                                    # Preserve the last_search_pages_fetched content
                                    pages_fetched=$(cat /tmp/last_search_pages_fetched 2>/dev/null || echo "$current_page")
                                    echo "$query" > /tmp/last_search_query
                                    echo "$new_page" > /tmp/last_search_page
                                    search_books "$query" "$new_page"
                                else
                                    echo "No more pages available"
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
                    if curl --insecure -s https://justrals.github.io/KindleFetch/install.sh | sh; then
                        echo "Update installed successfully!"
                        UPDATE_AVAILABLE=false
                        VERSION=$(load_version)
                        exec exit 0
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
