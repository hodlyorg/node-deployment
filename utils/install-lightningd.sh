#!/bin/bash

# Install options
TARGET_USER="bitcoin"
TARGET_GROUP="bitcoin"
SERVICE_NAME="lightningd"

# Resources
SERVICE_FILE_URL="https://raw.githubusercontent.com/ElementsProject/lightning/master/contrib/init/lightningd.service"

###############################################################################
# INTERNAL FUNCTIONS
###############################################################################

# Sanity checks
function sanity_checks() {
    # Check Execution privileges
    if [[ $EUID != 0 ]]; then
        echo "Please run as root"
        exit
    fi

    # Check if a "bitcoind" process is running
    if [[ $( pidof $SERVICE_NAME ) -ne 0 ]]; then
        echo "Lightningd service currently running. You must stop it first"
        exit
    fi
}

# Create user (and group), if not present
function create_user() {
    echo "Checking user and group ..."
    if [[ $(getent passwd $TARGET_USER) == "" ]]; then
        if [[ $(getent group $TARGET_GROUP) == "" ]]; then
            echo "Creating user [$TARGET_USER] and group [$TARGET_GROUP] ..."
            useradd -d $DATA_DIRECTORY -s $SHELL_ACCESS $TARGET_USER
        fi
    else
        if [[ $(getent group $TARGET_GROUP) == "" ]]; then
            groupadd $TARGET_GROUP
            usermod -g $TARGET_GROUP $TARGET_USER
        else 
            echo "Target user and group exist already, nothing to do ..."
        fi
    fi
}

# Add repository if not already installed
function install_ppa() {
    if [[ $(grep "^deb .*lightningnetwork.*$" /etc/apt/sources.list.d/*.list) == "" ]];
    then
        apt install -y software-properties-common
        add-apt-repository -u ppa:lightningnetwork/ppa
    else
        echo "Lightning Network PPA is already installed .."
    fi

    # Update
    apt update
    apt install lightningd
}


###############################################################################
# EXECUTION
###############################################################################

# Prep
sanity_checks
create_user
install_ppa
