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
    
    echo -n "Enter your Kindle downloads directory [It will be $BASE_DIR/your_directory. Only enter your_directory part.]: "
    read user_input
    if [ -n "$user_input" ]; then
        KINDLE_DOCUMENTS="$BASE_DIR/$user_input"
        if [ ! -d "$KINDLE_DOCUMENTS" ]; then
            mkdir -p "$KINDLE_DOCUMENTS" || {
                echo "Error: Failed to create directory $KINDLE_DOCUMENTS" >&2
                exit 1
            }
        fi
    else
        KINDLE_DOCUMENTS="$BASE_DIR/documents"
    fi
    echo -n "Create subfolders for books? [y/N]: "
    read subfolders_choice
    if [ "$subfolders_choice" = "y" ] || [ "$subfolders_choice" = "Y" ]; then
        CREATE_SUBFOLDERS="true"
    else
        CREATE_SUBFOLDERS="false"
    fi
    echo -n "Enable compact output? [y/N]: "
    read compact_choice
    if [ "$compact_choice" = "y" ] || [ "$compact_choice" = "Y" ]; then
        CREATE_SUBFOLDERS="true"
    else
        COMPACT_OUTPUT="false"
    fi

    save_config
    . "$CONFIG_FILE"
}