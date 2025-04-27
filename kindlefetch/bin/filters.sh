#!/bin/sh

filters_menu() {
    CURRENT_FILTERS_FILE="$SCRIPT_DIR/tmp/current_filters"
    CURRENT_PARAMS_FILE="$SCRIPT_DIR/tmp/current_filter_params"

    current_tab=1
    total_tabs=5

    mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null

    if [ -f "$CURRENT_FILTERS_FILE" ]; then
        . "$CURRENT_FILTERS_FILE" 2>/dev/null || {
            content_filter=""
            ext_filter=""
            lang_filter=""
            src_filter=""
            sort_filter=""
        }
    else
        content_filter=""
        ext_filter=""
        lang_filter=""
        src_filter=""
        sort_filter=""
    fi

    while true; do
        clear
        echo -e "
  ______ _ _ _                
 |  ____(_) | |               
 | |__   _| | |_ ___ _ __ ___ 
 |  __| | | | __/ _ \\ '__/ __|
 | |    | | | ||  __/ |  \\__ \\
 |_|    |_|_|\\__\\___|_|  |___/
"
        echo "╭──────────────────────────────────────╮"
        echo "│  1. Content  2. Format  3. Language  │"
        echo "│  4. Source  5. Sort  Enter - Apply   │"
        echo "╰──────────────────────────────────────╯"
        echo ""
        
        echo "Active Filters:"
        [ -n "$content_filter" ] && echo "  content: $content_filter"
        [ -n "$ext_filter" ] && echo "  ext: $ext_filter"
        [ -n "$lang_filter" ] && echo "  lang: $lang_filter"
        [ -n "$src_filter" ] && echo "  src: $src_filter"
        [ -n "$sort_filter" ] && echo "  sort: $sort_filter"
        echo ""
        
        case $current_tab in
            1) echo "── CONTENT TYPE ────────────────────────"
               echo "1) Nonfiction      5) Comic"
               echo "2) Fiction         6) Standards"
               echo "3) Unknown         7) Other"
               echo "4) Magazine        8) Musical Score"
               echo ""
               echo "0) Clear Filter" ;;
            2) echo "── FILE FORMAT ────────────────────────"
               echo "1) PDF      5) CBR"
               echo "2) EPUB     6) DJVU"
               echo "3) MOBI     7) CBZ"
               echo "4) FB2      8) TXT     9) AZW3"
               echo ""
               echo "0) Clear Filter" ;;
            3) echo "── LANGUAGE ───────────────────────────"
               echo "1) English (en)    4) German (de)"
               echo "2) Russian (ru)    5) French (fr)"
               echo "3) Spanish (es)    6) Custom Input"
               echo ""
               echo "0) Clear Filter" ;;
            4) echo "── SOURCE ────────────────────────────"
               echo "1) Library Genesis (lgli)"
               echo "2) Z-Library (zlib)"
               echo ""
               echo "0) Clear Filter" ;;
            5) echo "── SORT BY ───────────────────────────"
               echo "1) Newest          5) Newest Added"
               echo "2) Oldest          6) Oldest Added"
               echo "3) Largest         7) Random"
               echo "4) Smallest        8) Most Relevant"
               echo ""
               echo "0) Clear Filter" ;;
        esac

        echo ""
        echo -n "Choose option (or t[1-5] to switch tabs): "
        read choice

        case "$choice" in
            t1|t2|t3|t4|t5) current_tab=${choice#t} ;;
            0) case $current_tab in
                   1) content_filter="" ;;
                   2) ext_filter="" ;;
                   3) lang_filter="" ;;
                   4) src_filter="" ;;
                   5) sort_filter="" ;;
               esac ;;
            [1-9])
                case $current_tab in
                    1) case $choice in
                           1) content_filter="book_nonfiction" ;;
                           2) content_filter="book_fiction" ;;
                           3) content_filter="book_unknown" ;;
                           4) content_filter="magazine" ;;
                           5) content_filter="book_comic" ;;
                           6) content_filter="standards_document" ;;
                           7) content_filter="other" ;;
                           8) content_filter="musical_score" ;;
                       esac ;;
                    2) case $choice in
                           1) ext_filter="pdf" ;;
                           2) ext_filter="epub" ;;
                           3) ext_filter="mobi" ;;
                           4) ext_filter="fb2" ;;
                           5) ext_filter="cbr" ;;
                           6) ext_filter="djvu" ;;
                           7) ext_filter="cbz" ;;
                           8) ext_filter="txt" ;;
                           9) ext_filter="azw3" ;;
                       esac ;;
                    3) case $choice in
                           1) lang_filter="en" ;;
                           2) lang_filter="ru" ;;
                           3) lang_filter="es" ;;
                           4) lang_filter="de" ;;
                           5) lang_filter="fr" ;;
                           6) echo -n "Enter language code: "
                              read lang_code
                              lang_filter="$lang_code" ;;
                       esac ;;
                    4) case $choice in
                           1) src_filter="lgli" ;;
                           2) src_filter="zlib" ;;
                       esac ;;
                    5) case $choice in
                           1) sort_filter="newest" ;;
                           2) sort_filter="oldest" ;;
                           3) sort_filter="largest" ;;
                           4) sort_filter="smallest" ;;
                           5) sort_filter="newest_added" ;;
                           6) sort_filter="oldest_added" ;;
                           7) sort_filter="random" ;;
                           8) sort_filter="" ;;
                       esac ;;
                esac ;;
            "")
                {
                    echo "content_filter=\"$content_filter\""
                    echo "ext_filter=\"$ext_filter\""
                    echo "lang_filter=\"$lang_filter\""
                    echo "src_filter=\"$src_filter\""
                    echo "sort_filter=\"$sort_filter\""
                } > "$CURRENT_FILTERS_FILE"

                filter_string=""
                [ -n "$content_filter" ] && filter_string="${filter_string}&content=$content_filter"
                [ -n "$ext_filter" ] && filter_string="${filter_string}&ext=$ext_filter"
                [ -n "$lang_filter" ] && filter_string="${filter_string}&lang=$lang_filter"
                [ -n "$src_filter" ] && filter_string="${filter_string}&src=$src_filter"
                [ -n "$sort_filter" ] && filter_string="${filter_string}&sort=$sort_filter"
                echo "$filter_string" > "$CURRENT_PARAMS_FILE"

                return 0
                ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}