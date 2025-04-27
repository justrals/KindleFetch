#!/bin/sh

update() {
	if [ "$UPDATE_AVAILABLE" = true ]; then
        echo -n "Would you like to update? [y/N] "
        read confirm

        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo "Installing update..."
            if curl -s https://justrals.github.io/KindleFetch/install.sh | sh; then
                echo "Update installed successfully!"
                UPDATE_AVAILABLE=false
                VERSION=$(load_version)
                exec exit 0
            else
                echo "Failed to install update"
                sleep 2
            fi
        fi
    else
        echo "You're up-to-date!"
        sleep 2
    fi
}