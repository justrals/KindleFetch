#!/bin/sh

# RK patch 2026-08-12: LibGen direct search (Anna's Archive independent).
#
# Scrapes the libgen.li-family results table (index.php?req=...&curtab=f)
# into the exact JSON shape and /tmp state files that search_books() and
# its browse loop expect, so the existing display/select/download flow
# works unchanged. Records carry "lgli" in the description so the source
# menu offers the lgli download path; zlib is not offered (no zlib md5).
#
# lgli_search_fetch QUERY -> 0 if results were stored, 1 otherwise.

lgli_search_fetch() {
    local query="$1"
    [ -n "$query" ] || return 1

    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /+/g')

    local html_content=""
    local mirror_url
    for mirror_url in $LGLI_URL $LGLI_MIRROR_URLS; do
        mirror_url="${mirror_url%/}"
        [ -n "$mirror_url" ] || continue
        html_content="$(curl -f -s -L --max-time 20 \
            "$mirror_url/index.php?req=${encoded_query}&res=25&curtab=f")" \
            || html_content=""
        [ -n "$html_content" ] || continue
        echo "$html_content" | grep -q 'tablelibgen' || { html_content=""; continue; }
        LGLI_SEARCH_MIRROR="$mirror_url"
        break
    done
    [ -n "$html_content" ] || return 1

    local books
    books="$(echo "$html_content" \
        | sed 's/&amp;/\&/g; s/&quot;/"/g; s/&#0*39;/'"'"'/g; s/&nbsp;/ /g' \
        | awk -v mirror="$LGLI_SEARCH_MIRROR" '
        BEGIN {
            RS = "</tr>"
            print "["
            count = 0
        }
        NR > 1 {
            if ($0 !~ /ads\.php\?md5=/) next

            title = ""; author = ""; md5 = ""; format = ""
            year = ""; lang = ""; size = ""

            # md5 from the libgen mirror link ("/ads.php?md5=" is 13 chars)
            if (match($0, /\/ads\.php\?md5=[a-f0-9]{32}/)) {
                md5 = substr($0, RSTART+13, 32)
            }

            # title: text of the first edition.php anchor
            if (match($0, /href="edition\.php\?id=[0-9]+">[^<]+/)) {
                title = substr($0, RSTART, RLENGTH)
                sub(/.*">/, "", title)
            }

            # table cells
            ncells = split($0, cells, /<\/td>[ \t\r\n]*<td>/)
            if (ncells >= 8) {
                author = cells[2]
                year   = cells[4]
                lang   = cells[5]
                size   = cells[7]
                format = cells[8]
                for (f in cells) delete cells[f]
            }
            gsub(/<[^>]*>/, "", author)
            gsub(/<[^>]*>/, "", year)
            gsub(/<[^>]*>/, "", lang)
            gsub(/<[^>]*>/, "", size)
            gsub(/<[^>]*>/, "", format)
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", author)
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", year)
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", lang)
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", size)
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", format)

            # escape double quotes for JSON
            gsub(/"/, "\\\"", title)
            gsub(/"/, "\\\"", author)

            description = "LibGen lgli"
            if (lang != "")   description = description " · " lang
            if (year != "")   description = description " · " year
            if (size != "")   description = description " · " size

            if (title != "" && md5 != "") {
                if (count > 0) printf ",\n"
                printf "  {\"author\": \"%s\", \"format\": \"%s\", \"md5\": \"%s\", \"title\": \"%s\", \"url\": \"%s/ads.php?md5=%s\", \"description\": \"%s\"}", author, format, md5, title, mirror, md5, description
                count++
            }
        }
        END {
            print "\n]"
        }'
    )"

    local count
    count="$(echo "$books" | grep -o '"title":' | wc -l)"
    [ "$count" -gt 0 ] || return 1

    local last_page=$(( (count + RESULTS_PER_PAGE - 1) / RESULTS_PER_PAGE ))
    [ "$last_page" -lt 1 ] && last_page=1

    echo "$query" > "$TMP_DIR"/last_search_query
    echo "1" > "$TMP_DIR"/last_search_page
    echo "$last_page" > "$TMP_DIR"/last_search_last_page
    if [ "$last_page" -gt 1 ]; then
        echo "true" > "$TMP_DIR"/last_search_has_next
    else
        echo "false" > "$TMP_DIR"/last_search_has_next
    fi
    echo "false" > "$TMP_DIR"/last_search_has_prev
    echo "LibGen ($LGLI_SEARCH_MIRROR)" > "$TMP_DIR"/last_search_source
    echo "$books" > "$TMP_DIR"/search_results.json

    return 0
}
