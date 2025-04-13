#!/bin/sh

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
        echo "3. Toggle compact output: $COMPACT_OUTPUT"
        echo "4. Check for updates"
        echo "5. Back to main menu"
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
                if $COMPACT_OUTPUT; then
                    COMPACT_OUTPUT=false
                    echo "Condensed output disabled"
                else
                    COMPACT_OUTPUT=true
                    echo "Condensed output enabled"
                fi
                save_config
                ;;
            4)
                check_for_updates
                update
                ;;
            5)
                break
                ;;

            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}