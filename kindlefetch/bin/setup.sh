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
    
    echo -n "Enter your Kindle downloads directory [It will be $BASE_DIR/your_directory. Only enter your_directory part.]: "
    read -r downloads_dir
    if [ -n "$downloads_dir" ]; then
        KINDLE_DOCUMENTS="$BASE_DIR/$downloads_dir"
        if [ ! -d "$KINDLE_DOCUMENTS" ]; then
            mkdir -p "$KINDLE_DOCUMENTS" || {
                echo "Error: Failed to create directory $KINDLE_DOCUMENTS" >&2
                exit 1
            }
        fi
    else
        KINDLE_DOCUMENTS="$BASE_DIR/documents"
    fi

    echo -n "Do you want to sign into your zlib account? [Y/n]: "
    read -r zlib_login_choice
    if [ "$zlib_login_choice" = "n" ] || [ "$zlib_login_choice" = "N" ]; then
        ZLIB_AUTH=false
    else
        while true; do
            echo -n "Zlib email: "
            read -r zlib_email
            echo -n "Zlib password: "
            read -r zlib_password

            if zlib_login "$zlib_email" "$zlib_password"; then
                ZLIB_AUTH=true
                break
            else
                echo -n "Zlib login failed. Do you want to try again? [Y/n]: "
                read -r zlib_login_retry_choice
                if [ "$zlib_login_retry_choice" = "n" ] || [ "$zlib_login_retry_choice" = "N" ]; then
                    ZLIB_AUTH=false
                    break
                fi
            fi
        done
    fi

    echo -n "Use Cloudflare DNS? [y/N]: "
    read -r dns_choice
    if [ "$dns_choice" = "y" ] || [ "$dns_choice" = "Y" ]; then
        ENFORCE_DNS=true
    else
        ENFORCE_DNS=false
    fi

    save_config
    . "$CONFIG_FILE"
}
