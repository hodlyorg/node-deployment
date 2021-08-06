#!/bin/bash

# Target version
LIGHTNINGD_VERSION="v0.10.0"
LIGHTNINGD_TARBALL="clightning-${LIGHTNINGD_VERSION}-Ubuntu-20.04.tar.xz"
LIGHTNINGD_URL="https://github.com/ElementsProject/lightning/releases/download/${LIGHTNINGD_VERSION}/${LIGHTNINGD_TARBALL}"
LIGHTNINGD_ASC_URL="https://github.com/ElementsProject/lightning/releases/download/${LIGHTNINGD_VERSION}/SHA256SUMS"

# Install options
TARGET_USER="bitcoin"
TARGET_GROUP="bitcoin"
INSTALL_DIRECTORY="/opt/lightningd"
LIBEXEC_INSTALL_DIRECTORY="${INSTALL_DIRECTORY}/libexec/c-lightning"
LIBEXEC_TARGET_DIRECTORY="/usr/local/libexec/c-lightning"
SHARE_INSTALL_DIRECTORY="${INSTALL_DIRECTORY}/share"
DATA_DIRECTORY="/var/lib/lightningd"
CONFIG_DIRECTORY="/etc/lightning"
SERVICE_DIRECTORY="/usr/lib/systemd/system"
SHELL_ACCESS="/usr/sbin/nologin"
SERVICE_NAME="lightningd"

# Resources
SERVICE_FILE_URL="https://raw.githubusercontent.com/hodlyorg/node-deployment/main/systemd/lightningd.service"

# Enable pipefail
set -euo pipefail

###############################################################################
# INTERNAL FUNCTIONS
###############################################################################

# Sanity checks
function sanity_checks() {
    ################################################
    # Check Execution privileges
    if [[ $EUID != 0 ]]; then
        echo "Please run as root"
        exit
    fi

    ################################################
    # Check if a "lightningd" process is running
    if [[ $( pidof $SERVICE_NAME ) -ne 0 ]]; then
        echo "Lightningd service currently running. You must stop it first"
        exit
    fi
}

# Create required directories function
function create_dirs() {
    ################################################
    # Create install directory if needed
    if [[ ! -d $INSTALL_DIRECTORY ]]; then
        echo "Creating target directory: ${INSTALL_DIRECTORY}"
        mkdir $INSTALL_DIRECTORY
    fi

    ################################################
    # Create data directory if needed
    if [[ ! -d $DATA_DIRECTORY ]]; then
        echo "Creating target directory: ${DATA_DIRECTORY}"
        mkdir $DATA_DIRECTORY
    fi

    ################################################
    # Create config directory if needed
    if [[ ! -d $CONFIG_DIRECTORY ]]; then
        echo "Creating config directory: ${CONFIG_DIRECTORY}"
        mkdir $CONFIG_DIRECTORY
    fi

    ################################################
    # Create service directory if needed
    if [[ ! -d $SERVICE_DIRECTORY ]]; then
        echo "Creating service directory: ${SERVICE_DIRECTORY}"
        mkdir $SERVICE_DIRECTORY
    fi

    ################################################
    # Create Local libexec directory if needed
    if [[ ! -d /usr/local/libexec ]]; then
        echo "Creating config directory: /usr/local/libexec"
        mkdir -p /usr/local/libexec
    fi

    ################################################
    # Create run directory if needed
    if [[ ! -d $RUN_DIRECTORY ]]; then
        echo "Creating config directory: ${RUN_DIRECTORY}"
        mkdir $RUN_DIRECTORY
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
function download_and_install() {
    pushd $INSTALL_DIRECTORY

    ################################################
    # Make sure the system is up to date
    echo "Updating system dependencies ..."
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates wget libpq5 postgresql postgresql-contrib

    ################################################
    # Download Tarball and Checksums
    echo "Downloading release [${LIGHTNINGD_VERSION}] ..."
    wget -qO $LIGHTNINGD_TARBALL "$LIGHTNINGD_URL"
    wget -qO lightningd.asc "$LIGHTNINGD_ASC_URL"

    ################################################
    # Extract the tarball's checksum from the released .asc and verify it
    echo "Verifying release ..."
    grep $LIGHTNINGD_TARBALL lightningd.asc | tee SHA256SUMS.asc
    sha256sum -c SHA256SUMS.asc

    ################################################
    # Extract
    echo "Extracting binaries ..."
    tar -xvf $LIGHTNINGD_TARBALL --strip-components=2

    ################################################
    # Cleanup
    echo "Cleaning up ..."
    rm $LIGHTNINGD_TARBALL
    rm lightningd.asc
    rm SHA256SUMS.asc

    ################################################
    # Update permissions
    echo "Updating permissions ..."

    # Install directory
    chown -R root:root $INSTALL_DIRECTORY
    chmod -R 0710 $INSTALL_DIRECTORY

    # Data directory permissions
    chown -R $TARGET_USER:$TARGET_GROUP $DATA_DIRECTORY
    chmod -R 0710 $DATA_DIRECTORY

    # Files that need to go under /usr/share
    find $SHARE_INSTALL_DIRECTORY -type f -exec chmod 644 -- {} +

    ################################################
    # Install executables
    echo "Installing executables"
    install -m 0755 -o root -g root -t /usr/local/bin $INSTALL_DIRECTORY/bin/*
    ln -sf /usr/local/bin/lightningd /usr/bin/lightningd

    ################################################
    # Install libexec dependencies
    cp -r $LIBEXEC_INSTALL_DIRECTORY /usr/local/libexec
    chown -R root:root $LIBEXEC_TARGET_DIRECTORY
    chmod -R 0755 $LIBEXEC_TARGET_DIRECTORY

    ################################################
    # Install docs and man pages
    echo "Installing docs and man pages"
    cp -r $SHARE_INSTALL_DIRECTORY/* /usr/share/

    # Update man db
    mandb

    popd
}

# Service setup
function setup_service() {
    ################################################
    # Install default config file if no file exists
    if [[ ! -f $CONFIG_DIRECTORY/lightningd.conf ]]; then
        # Deploy default config (empty)
        echo "Installing default config"
        touch $CONFIG_DIRECTORY/lightningd.conf
        chmod 0710 $CONFIG_DIRECTORY
        chmod 0640 $CONFIG_DIRECTORY/lightningd.conf
        chown -R root:$TARGET_GROUP $CONFIG_DIRECTORY
    fi

    ################################################
    # Install default service unit if one is not present
    if [[ ! -f $SERVICE_DIRECTORY/lightningd.service ]]; then
        # Download and deploy service unit
        echo "Installing systemd service unit ..."
        wget -qO lightningd.service "$SERVICE_FILE_URL"
        mv lightningd.service $SERVICE_DIRECTORY/
        systemctl daemon-reload
    fi
}

###############################################################################
# EXECUTION
###############################################################################

# Prep
sanity_checks
create_dirs
create_user

# Install
download_and_install
setup_service
