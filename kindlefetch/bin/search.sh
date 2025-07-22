#!/bin/sh

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
    
    i=$((count-1))
    while [ $i -ge 0 ]; do
        book_info=$(echo "$1" | awk -v i=$i 'BEGIN{RS="\\{"; FS="\\}"} NR==i+2{print $1}')
        title=$(get_json_value "$book_info" "title")
        author=$(get_json_value "$book_info" "author")
        format=$(get_json_value "$book_info" "format")
        description=$(get_json_value "$book_info" "description")
        
        if ! $COMPACT_OUTPUT; then
            printf "%2d. %s\n" $((i+1)) "$title"
            [ -n "$description" ] && [ "$description" != "null" ] && echo "    $description"
            echo ""
        else
            printf "%2d. %s by %s in %s format\n" $((i+1)) "$title" "$author" "$format"
            # [ -n "$description" ] && [ "$description" != "null" ] && echo "    $description"
            echo ""
        fi
        
        i=$((i-1))
    done
    
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

    local filters=""
    if [ -f "$SCRIPT_DIR"/tmp/current_filter_params ]; then
        filters=$(cat "$SCRIPT_DIR/tmp/current_filter_params")
    fi
    
    encoded_query=$(echo "$query" | sed 's/ /+/g')
    search_url="$ANNAS_URL/search?page=${page}&q=${encoded_query}${filters}"
    local html_content=$(curl -s "$search_url") || html_content=$(curl -s -x "$PROXY_URL" "$search_url")
    
    local last_page=$(echo "$html_content" | grep -o 'page=[0-9]\+"' | sort -nr | head -1 | cut -d= -f2 | tr -d '"')
    [ -z "$last_page" ] && last_page=1
    
    local has_prev="false"
    [ "$page" -gt 1 ] && has_prev="true"
    
    local has_next="false"
    [ "$page" -lt "$last_page" ] && has_next="true"

    echo "$query" > $TMP_DIR/last_search_query
    echo "$page" > $TMP_DIR/last_search_page
    echo "$last_page" > $TMP_DIR/last_search_last_page
    echo "$has_next" > $TMP_DIR/last_search_has_next
    echo "$has_prev" > $TMP_DIR/last_search_has_prev
    
    local books=$(echo "$html_content" | awk '
        BEGIN {
            RS="<div class=\"h-\\[110px\\] flex flex-col justify-center \">";
            FS=">";
            print "["
            book_count = 0
        }
        NR > 1 {
            link = ""; md5 = ""; title = ""; author = ""; format = "null"; description = "null"
            
            # Extract MD5 and link
            if ($0 ~ /<a href="\/md5\//) {
                link_start = index($0, "/md5/")
                link_end = index(substr($0, link_start), "\"")
                if (link_end > 0) {
                    link = substr($0, link_start, link_end - 1)
                    md5 = substr(link, 6, 32)
                }
            }
            
            # Extract title
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
            
            # Extract author
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

            # Extract format
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
            
            # Extract description
            if ($0 ~ /class="[^"]*text-gray-500[^"]*"/) {
                desc_start = index($0, "text-gray-500")
                desc_part = substr($0, desc_start)
                desc_start = index(desc_part, ">") + 1
                desc_end = index(desc_part, "</div>")
                if (desc_end > 0) {
                    description = substr(desc_part, desc_start, desc_end - desc_start)
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", description)
                    gsub(/"/, "\\\"", description)
                    description = "\"" description "\""
                }
            }

            gsub(/🚀/, "Partner Server", description)
            gsub(/📗|📘|📕|📰|💬|📝|🤨|🎶|✅/, "", description)
            
            if (title != "") {
                if (book_count > 0) printf ",\n"
                printf "  {\"author\":\"%s\",\"format\":%s,\"md5\":\"%s\",\"title\":\"%s\",\"url\":\"$ANNAS_URL%s\",\"description\":%s}", 
                    author, format, md5, title, link, description
                book_count++
            }
        }
        END { print "\n]" }
    ')
    
    echo "$books" > $TMP_DIR/search_results.json

    while true; do
        query=$(cat $TMP_DIR/last_search_query 2>/dev/null)
        current_page=$(cat $TMP_DIR/last_search_page 2>/dev/null || echo 1)
        last_page=$(cat $TMP_DIR/last_search_last_page 2>/dev/null || echo 1)
        has_next=$(cat $TMP_DIR/last_search_has_next 2>/dev/null || echo "false")
        has_prev=$(cat $TMP_DIR/last_search_has_prev 2>/dev/null || echo "false")
        books=$(cat $TMP_DIR/search_results.json 2>/dev/null)
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
                        local book_info=$(awk -v i="$choice" 'BEGIN{RS="\\{"; FS="\\}"} NR==i+1{print $1}' $TMP_DIR/search_results.json)

                        local lgli_available=false
                        local zlib_available=false

                        if echo "$book_info" | grep -q "lgli"; then
                            local lgli_available=true
                        fi
                        if echo "$book_info" | grep -q "zlib"; then
                            local zlib_available=true
                        fi

                        if [ "$lgli_available" = false ] && [ "$zlib_available" = false ]; then
                            echo "There are no available sources for this book right now. :["
                        fi

                        if [ "$lgli_available" = true ]; then
                            echo "1. lgli"
                        fi
                        if [ "$zlib_available" = true ]; then
                            echo "2. zlib"
                        fi
                        echo "3. Cancel download"

                        while true; do
                            echo -n "Choose source to proceed with: "
                            read source_choice

                            case "$source_choice" in
                                1)
                                    if [ "$lgli_available" = true ]; then
                                        echo "Proceeding with lgli..."
                                        if ! lgli_download "$choice"; then
                                            echo "Download from lgli failed."
                                            sleep 2
                                        else
                                            break
                                        fi
                                    else
                                        echo "Invalid choice."
                                    fi
                                    ;;
                                2)
                                    if [ "$zlib_available" = true ]; then
                                        echo "Proceeding with zlib..."
                                        if ! zlib_download "$choice"; then
                                            echo "Download from zlib failed."
                                            sleep 2
                                        else
                                            break
                                        fi
                                    else
                                        echo "Invalid choice."
                                    fi
                                    ;;
                                3)
                                    break
                                    ;;
                                *)
                                    echo "Invalid choice."
                                    ;;
                            esac
                        done

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
}