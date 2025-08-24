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
    
    local last_page=$(echo "$html_content" | grep -o 'page=[0-9]\+"' | sort -t= -k2 -nr | head -1 | cut -d= -f2 | tr -d '"')
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
    
    local books=$(echo $html_content | awk '
        BEGIN {
            RS = "<div class=\"flex pt-3 pb-3 border-b last:border-b-0 border-gray-100\">"
            print "["
            count = 0
        }
        NR > 1 {
            title = ""; author = ""; md5 = ""; format = ""; description = ""
        
            # md5
            if (match($0, /href="\/md5\/[a-f0-9]{32}"/)) {
                md5 = substr($0, RSTART+11, 32)
            }
        
            # title
            if (match($0, /<div class="font-bold text-violet-900 line-clamp-\[5\]" data-content="[^"]+"/)) {
                block = substr($0, RSTART, RLENGTH)
                if (match(block, /data-content="[^"]+"/)) {
                    title = substr(block, RSTART+14, RLENGTH-15)
                }
            }
        
            # author
            if ($0 ~ /<div[^>]*class="[^"]*font-bold[^"]*text-amber-900[^"]*line-clamp-\[2\][^"]*"/) {
                if (match($0, /<div[^>]*class="[^"]*font-bold[^"]*text-amber-900[^"]*line-clamp-\[2\][^"]*" data-content="[^"]+"/)) {
                    block = substr($0, RSTART, RLENGTH)
                    if (match(block, /data-content="[^"]+"/)) {
                        author = substr(block, RSTART+14, RLENGTH-15)
                    }
                }
            }
        
            # format
            if (match($0, /<div class="text-gray-800[^>]*>[^<]+/)) {
                line = substr($0, RSTART, RLENGTH)
                if (match(line, />[^<]+/)) {
                    content = substr(line, RSTART+1, RLENGTH-1)
                    n = split(content, parts, " · ")
                    if (n >= 2) {
                        format = parts[2]
                    }
                }
            }
            
            # description
            if (match($0, /<div[^>]*class="[^"]*text-gray-800[^"]*font-semibold[^"]*text-sm[^"]*leading-\[1\.2\][^"]*mt-2[^"]*"[^>]*>.*?<\/div>/)) {
                line = substr($0, RSTART, RLENGTH)

                gsub(/<script[^>]*>[^<]*(<[^>]*>[^<]*)*<\/script>/, "", line)

                gsub(/<a[^>]*>[^<]*(<[^>]*>[^<]*)*<\/a>/, "", line)

                gsub(/<[^>]*>/, "", line)

                gsub(/&[#a-zA-Z0-9]+;/, "", line)

                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", line)

                description = line
            }
        
            # emoji replacements
            gsub(/🚀/, "Partner Server", description)
            gsub(/📗|📘|📕|📰|💬|📝|🤨|🎶|✅/, "", description)
        
            # escape double quotes
            gsub(/"/, "\\\"", title)
            gsub(/"/, "\\\"", author)
            gsub(/"/, "\\\"", description)
        
            if (title != "") {
                if (count > 0) {
                    printf ",\n"
                }
                printf "  {\"author\": \"%s\", \"format\": \"%s\", \"md5\": \"%s\", \"title\": \"%s\", \"url\": \"%s/md5/%s\", \"description\": \"%s\"}", author, format, md5, title, base_url, md5, description
                count++
            }
        }
        END {
            print "\n]"
        }'
    )
    
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
                        # if [ "$zlib_available" = true ]; then
                        #     echo "2. zlib"
                        # fi
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
                                # 2)
                                #     if [ "$zlib_available" = true ]; then
                                #         echo "Proceeding with zlib..."
                                #         if ! zlib_download "$choice"; then
                                #             echo "Download from zlib failed."
                                #             sleep 2
                                #         else
                                #             break
                                #         fi
                                #     else
                                #         echo "Invalid choice."
                                #     fi
                                #     ;;
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
