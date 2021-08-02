#!/bin/bash

###############################################################################
# CONFIG
###############################################################################

# Target version
BITCOIN_VERSION="0.21.1"
BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz"
BITCOIN_URL="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_TARBALL}"
BITCOIN_ASC_URL="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc"
BITCOIN_DIST_BINARIES_DIRECTORY="bitcoin-${BITCOIN_VERSION}/bin"

# Install options
TARGET_USER="bitcoin"
TARGET_GROUP="bitcoin"
INSTALL_DIRECTORY="/opt/bitcoind"
DATA_DIRECTORY="/var/lib/bitcoind"
CONFIG_DIRECTORY="/etc/bitcoin"
SERVICE_DIRECTORY="/usr/lib/systemd/system"
SHELL_ACCESS="/usr/sbin/nologin"
SERVICE_NAME="bitcoind"

# Resources
SERVICE_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/init/bitcoind.service"
CONFIG_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/examples/bitcoin.conf"

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
    # Check if a "bitcoind" process is running
    if [[ $( pidof $SERVICE_NAME ) -ne 0 ]]; then
        echo "Bitcoind service currently running. You must stop it first"
        exit
    fi
}

# Create user (and group), if not present
function create_user() {
    echo "Checking user and group ..."
    if [[ $(getent passwd $TARGET_USER) == "" ]]; then
        if [[ $(getent group $TARGET_GROUP) == "" ]]; then
            echo "Creating user [${TARGET_USER}] and group [${TARGET_GROUP}] ..."
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
}

# Install binaries
function download_and_install() {
    pushd $INSTALL_DIRECTORY

    ################################################
    # Make sure the system is up to date
    echo "Updating system dependencies ..."
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates dirmngr wget

    ################################################
    # Download Tarball and Checksums
    echo "Downloading release [${BITCOIN_VERSION}] ..."
    wget -qO $BITCOIN_TARBALL "$BITCOIN_URL"
    wget -qO bitcoin.asc "$BITCOIN_ASC_URL"

    ################################################
    # Extract the tarball's checksum from the released .asc and verify it
    echo "Verifying release ..."
    grep $BITCOIN_TARBALL bitcoin.asc | tee SHA256SUMS.asc
    sha256sum -c SHA256SUMS.asc

    ################################################
    # Extract
    echo "Extracting binaries ..."
    tar -xzvf $BITCOIN_TARBALL $BITCOIN_DIST_BINARIES_DIRECTORY/ --strip-components=1

    ################################################
    # Cleanup
    echo "Cleaning up ..."
    rm $BITCOIN_TARBALL
    rm bitcoin.asc
    rm SHA256SUMS.asc
    rm $INSTALL_DIRECTORY/bin/bitcoin-qt

    ################################################
    # Update permissions
    echo "Updating permissions ..."

    # Install folder
    chown -R root:root $INSTALL_DIRECTORY
    chmod -R 0710 $INSTALL_DIRECTORY

    # Data folder
    chown -R $TARGET_USER:$TARGET_GROUP $DATA_DIRECTORY
    chmod -R 0710 $DATA_DIRECTORY

    # Run tests
    $INSTALL_DIRECTORY/bin/test_bitcoin

    ################################################
    # Install executables
    install -m 0755 -o root -g root -t /usr/local/bin $INSTALL_DIRECTORY/bin/*
    ln -sf /usr/local/bin/bitcoind /usr/bin/bitcoind

    popd
}

# Service setup (conf and service files)
function setup_service() {
    ################################################
    # Install default config file if no file exists
    if [[ ! -f $CONFIG_DIRECTORY/bitcoind.conf ]]; then
        if [[ ! -d $CONFIG_DIRECTORY ]]; then
            echo "Creating config directory: ${CONFIG_DIRECTORY}"
            mkdir $CONFIG_DIRECTORY
        fi

        # Deploy default config
        echo "Installing default config"
        wget -qO bitcoind.conf "$CONFIG_FILE_URL"
        mv bitcoind.conf $CONFIG_DIRECTORY/bitcoind.conf
        chmod 0710 $CONFIG_DIRECTORY
        chmod 0640 $CONFIG_DIRECTORY/bitcoind.conf
        chown -R root:$TARGET_GROUP $CONFIG_DIRECTORY
    fi

    ################################################
    # Install default service unit if one is not present
    if [[ ! -f $SERVICE_DIRECTORY/bitcoind.service ]]; then
        # Download and deploy service unit
        echo "Installing systemd service unit ..."
        wget -qO bitcoind.service "$SERVICE_FILE_URL"
        mv bitcoind.service $SERVICE_DIRECTORY/
        systemctl daemon-reload
    fi
}

###############################################################################
# EXECUTION
###############################################################################

# Prep
sanity_checks
create_user
create_dirs

# Install
download_and_install
setup_service

echo "Bitcoin v${BITCOIN_VERSION} is now installed and ready to use!"