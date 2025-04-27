#!/bin/sh

# KindleFetch
# Made by justrals
# https://github.com/justrals/KindleFetch

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/kindlefetch_config"
LINK_CONFIG_FILE="$SCRIPT_DIR/link_config"
VERSION_FILE="$SCRIPT_DIR/.version"

UPDATE_AVAILABLE=false

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    echo "Press any key to exit."
    read -n 1 -s
    exit 1
fi

# Script imports
. "$SCRIPT_DIR/downloads/zlib_download.sh"
. "$SCRIPT_DIR/downloads/lgli_download.sh"
. "$SCRIPT_DIR/filters.sh"
. "$SCRIPT_DIR/search.sh"
. "$SCRIPT_DIR/misc.sh"
. "$SCRIPT_DIR/local_books.sh"
. "$SCRIPT_DIR/update.sh"
. "$SCRIPT_DIR/setup.sh"
. "$SCRIPT_DIR/settings.sh"

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
        cat /tmp/current_filters
        if $UPDATE_AVAILABLE; then
            echo "Update available! Select option 6 to install."
            echo ""
        fi
        echo "1. Search and download books"
        echo "2. Filter search results"
        echo "3. List my books"
        echo "4. Settings"
        echo "5. Exit"
        if $UPDATE_AVAILABLE; then
            echo ""
            echo "6. Install update"
        fi
        echo ""
        echo -n "Choose option: "
        read choice
        
        case "$choice" in
            1)
                search_books
                ;;
            2)
                filters_menu
                ;;
            3)
                list_local_books
                ;;
            4)
                settings_menu
                ;;
            5)
                cleanup
                exit 0
                ;;
            6)  
                if $UPDATE_AVAILABLE; then
                    update
                fi
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}

trap cleanup EXIT
main_menu