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
                echo -n "Enter your new Kindle downloads directory [It will be $BASE_DIR/your_directory. Only enter your_directory part.]: "
                read new_dir
                if [ -n "$new_dir" ]; then
                    KINDLE_DOCUMENTS="$BASE_DIR/$new_dir"
                    if [ ! -d "$KINDLE_DOCUMENTS" ]; then
                        mkdir -p "$KINDLE_DOCUMENTS" || {
                            echo "Error: Failed to create directory $KINDLE_DOCUMENTS" >&2
                            exit 1
                        }
                    fi
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