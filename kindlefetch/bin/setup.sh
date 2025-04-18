#!/bin/sh

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
    
    echo -n "Enter your Kindle downloads directory [default: /mnt/us/documents]: "
    read user_input
    if [ -n "$user_input" ]; then
        KINDLE_DOCUMENTS="$user_input"
    else
        KINDLE_DOCUMENTS="/mnt/us/documents"
    fi
    echo -n "Create subfolders for books? (true/false): "
    read subfolders_choice
    if [ "$subfolders_choice" = "true" ] || [ "$subfolders_choice" = "false" ]; then
        CREATE_SUBFOLDERS="$subfolders_choice"
    else
        CREATE_SUBFOLDERS="false"
    fi
    echo -n "Enable compact output? (true/false): "
    read compact_choice
    if [ "$compact_choice" = "true" ] || [ "$compact_choice" = "false" ]; then
        COMPACT_OUTPUT="$compact_choice"
    else
        COMPACT_OUTPUT="false"
    fi

    save_config
    . "$CONFIG_FILE"
}