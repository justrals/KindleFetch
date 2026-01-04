#!/bin/sh

# KindleFetch
# Made by justrals
# https://github.com/justrals/KindleFetch

# Variables
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$SCRIPT_DIR/kindlefetch_config"
LINK_CONFIG_FILE="$SCRIPT_DIR/link_config"
VERSION_FILE="$SCRIPT_DIR/.version"
ZLIB_COOKIES_FILE="$SCRIPT_DIR/zlib_cookies.txt"
TMP_DIR="/tmp"
BASE_DIR="/mnt/us"

UPDATE_AVAILABLE=false
CREATE_SUBFOLDERS=false
COMPACT_OUTPUT=false

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo -n "This script must run on a Kindle device. Do you want to run it anyway? [y/N]: "
    read -r kindle_override_choice
    if [ "$kindle_override_choice" = "y" ] || [ "$kindle_override_choice" = "Y" ]; then
        :
    else
        exit 1
    fi
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
    if [ "${ENFORCE_DNS}" = true ];
    	then change_dns
    fi
    if [ "${ANNAS_TLD}" = "" ];
    	then ANNAS_TLD="org"
    fi
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
        read -r choice
        
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
