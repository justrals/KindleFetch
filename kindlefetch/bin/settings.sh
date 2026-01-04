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
        if [[ "$ZLIB_AUTH" == "true" ]]; then
            echo "2. Re-log into zlib account. Currently logged-in as $ZLIB_USERNAME"
        else
            echo "2. Sign into zlib account"
        fi
        echo "3. Toggle subfolders for books: $CREATE_SUBFOLDERS"
        echo "4. Toggle compact output: $COMPACT_OUTPUT"
        echo "5. Toggle Cloudflare DNS: $ENFORCE_DNS"
        echo "6. Change the top level domain (current: $ANNAS_TLD)"
        echo "7. Check for updates"
        echo "8. Back to main menu"
        echo ""
        echo -n "Choose option: "
        read -r choice
        
        case "$choice" in
            1)
                echo -n "Enter your new Kindle downloads directory [It will be $BASE_DIR/your_directory. Only enter your_directory part.]: "
                read -r new_dir
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
                while true; do
                    echo -n "Zlib email: "
                    read -r zlib_email
                    echo -n "Zlib password: "
                    read -r zlib_password

                    if zlib_login "$zlib_email" "$zlib_password"; then
                        ZLIB_AUTH=true
                        save_config
                        sleep 2
                        break
                    else
                        echo -n "Zlib login failed. Do you want to try again? [Y/n]: "
                        read -r zlib_login_retry_choice
                        if [ "$zlib_login_retry_choice" = "n" ] || [ "$zlib_login_retry_choice" = "N" ]; then
                            ZLIB_AUTH=false
                            save_config
                            break
                        fi
                    fi
                done
                ;;

            3)
                if $CREATE_SUBFOLDERS; then
                    CREATE_SUBFOLDERS=false
                    echo "Subfolders disabled"
                else
                    CREATE_SUBFOLDERS=true
                    echo "Subfolders enabled"
                fi
                save_config
                ;;
            4)
                if $COMPACT_OUTPUT; then
                    COMPACT_OUTPUT=false
                    echo "Condensed output disabled"
                else
                    COMPACT_OUTPUT=true
                    echo "Condensed output enabled"
                fi
                save_config
                ;;
            5)
                if $ENFORCE_DNS; then
                    ENFORCE_DNS=false
                    echo "Cloudflare DNS disabled, using provider DNS from next Wifi reconnection"
                else
                    ENFORCE_DNS=true
                    change_dns
                    echo "Cloudflare DNS enabled"
                fi
                save_config
                ;;
            6)
                echo -n "Enter new top level domain for annas-archive (e.g., li, org): "
                read -r new_tld
                if [ -n "$new_tld" ]; then
                    ANNAS_TLD="$new_tld"
                    save_config
                else
                    echo "Invalid input. Top level domain not changed."
                    sleep 2
                fi
                ;;
            7)
                check_for_updates
                update
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}
