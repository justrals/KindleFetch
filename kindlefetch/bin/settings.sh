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
        echo "6. Search results per page: $RESULTS_PER_PAGE"
        echo "7. Check for updates"
        echo ""
        echo "Current mirrors:"
        echo "   Anna's Archive - ${ANNAS_URL}"
        echo "   Library Genesis - ${LGLI_URL}"
        echo "   ZLibrary - ${ZLIB_URL}"
        echo "8. Change URLs"
        echo ""
        echo "q. Back to main menu"
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
                            echo "Failed to create directory $KINDLE_DOCUMENTS" >&2
                            return 1
                        }
                    fi
                    save_config
                fi
                ;;
            2)
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
                echo -n "Enter number of search results per page: "
                read -r new_rpp
                if [ "$new_rpp" -gt 0 ] 2>/dev/null && [ "$new_rpp" -le 100 ]; then
                    RESULTS_PER_PAGE="$new_rpp"
                    save_config
                else
                    echo "Invalid input"
                    sleep 2
                fi
                ;;
            7)
                check_for_updates
                update
                ;;
            8)
                echo ""
                echo "Which URL do you want to change?"
                echo "1. Anna's Archive"
                echo "2. Library Genesis"
                echo "3. ZLibrary"
                echo ""
                echo "q. Cancel"
                echo ""
                echo -n "Choose option: "
                read -r choice

                case "$choice" in
                    1)
                        echo -n "Enter new URL for Anna's Archive: "
                        read -r new_annas_url

                        working_url=$(find_working_url "$new_annas_url")
                        if [ -z "$working_url" ]; then
                            echo "Failed to connect to ${new_annas_url}."
                            echo -n "Are you sure you want to set this URL anyway? [y/N]: "
                            read -r confirm
                            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                                echo "URL not changed."
                                sleep 2
                                continue
                            else
                                working_url="$new_annas_url"
                            fi
                        fi

                        ANNAS_URL="$working_url"
                        echo "Anna's Archive URL set to $ANNAS_URL"
                        save_config
                        sleep 2
                        ;;
                    2)
                        echo -n "Enter new URL for Library Genesis: "
                        read -r new_lgli_url

                        working_url=$(find_working_url "$new_lgli_url")
                        if [ -z "$working_url" ]; then
                            echo "Failed to connect to ${new_lgli_url}."
                            echo -n "Are you sure you want to set this URL anyway? [y/N]: "
                            read -r confirm
                            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                                echo "URL not changed."
                                sleep 2
                                continue
                            else
                                working_url="$new_lgli_url"
                            fi
                        fi

                        LGLI_URL="$working_url"
                        echo "Library Genesis URL set to $LGLI_URL"
                        save_config
                        sleep 2
                        ;;
                    3)
                        echo -n "Enter new URL for ZLibrary: "
                        read -r new_zlib_url

                        working_url=$(find_working_url "$new_zlib_url")
                        if [ -z "$working_url" ]; then
                            echo "Failed to connect to ${new_zlib_url}."
                            echo -n "Are you sure you want to set this URL anyway? [y/N]: "
                            read -r confirm
                            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                                echo "URL not changed."
                                sleep 2
                                continue
                            else
                                working_url="$new_zlib_url"
                            fi
                        fi

                        ZLIB_URL="$working_url"
                        echo "ZLibrary URL set to $ZLIB_URL"
                        save_config
                        sleep 2
                        ;;
                    [qQ])
                        continue
                        ;;
                    *)
                        echo "Invalid choice"
                        sleep 2
                        ;;
                esac
                ;;
            [qQ])
                break
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}
