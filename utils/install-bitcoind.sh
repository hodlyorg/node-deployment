#!/bin/bash

###############################################################################
# CONFIG
###############################################################################

# Target version
BITCOIN_VERSION="0.21.1"
BITCOIN_TARBALL="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz"
BITCOIN_URL="https://bitcoincore.org/bin/bitcoin-core-$BITCOIN_VERSION/$BITCOIN_TARBALL"
BITCOIN_ASC_URL="https://bitcoincore.org/bin/bitcoin-core-$BITCOIN_VERSION/SHA256SUMS.asc"
BITCOIN_DIST_BINARIES_DIRECTORY="bitcoin-$BITCOIN_VERSION/bin"

# Install options
TARGET_USER="bitcoin"
TARGET_GROUP="bitcoin"
INSTALL_DIRECTORY="/opt/bitcoind"
DATA_DIRECTORY="/var/lib/bitcoind"
CONFIG_DIRECTORY="/etc/bitcoin"
SERVICE_DIRECTORY="/usr/lib/systemd/system"
RUN_DIRECTORY="/run/bitcoind"
SHELL_ACCESS="/usr/sbin/nologin"
SERVICE_NAME="bitcoind"

# Resources
SERVICE_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/init/bitcoind.service"
CONFIG_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/examples/bitcoin.conf"

# Enable pipefail
set -euxo pipefail

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
    if [[ $( pidof $SERVICE_NAME ) != 0 ]]; then
        echo "Bitcoind service currently running. You must stop it first"
    fi
}

# Create user (and group), if not present
function create_user() {
    echo "Checking user and group .."
    if [[ ! getent passwd $TARGET_USER ]]; then
        if [[ ! getent group $TARGET_GROUP ]]; then
            echo "Creating user [$TARGET_USER] and group [$TARGET_GROUP] .."
            useradd -d $DATA_DIRECTORY -s $SHELL_ACCESS $TARGET_USER
        fi
    else
        if [[ ! getent group $TARGET_GROUP ]]; then
            echo "ERROR: User [$TARGET_USER] exists already, but the group [$TARGET_GROUP] cannot be found. Either remove the user or manually create the required group and associated with it"
            exit
        else 
            echo "Target user and group exist already, nothing to do .."
        fi
    fi
}

# Create required directories function
function create_dirs() {
    # Create install directory if needed
    if [[ ! -d $INSTALL_DIRECTORY ]]; then
        echo "Creating target directory: $INSTALL_DIRECTORY"
        mkdir $INSTALL_DIRECTORY
    fi

    # Create config directory if needed
    if [[ ! -d $CONFIG_DIRECTORY ]]; then
        echo "Creating config directory: $CONFIG_DIRECTORY"
        mkdir $CONFIG_DIRECTORY
    fi

    # Create run directory if needed
    if [[ ! -d $RUN_DIRECTORY ]]; then
        echo "Creating run directory: $RUN_DIRECTORY"
        mkdir $RUN_DIRECTORY
        chown $TARGET_USER:$TARGET_GROUP $RUN_DIRECTORY
    fi
}

# Install binaries
function download_and_install() {
    # Make sure the system is up to date
    echo "Updating System .."
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates dirmngr wget

    # Download Tarball and Checksums
    echo "Downloading release [$BITCOIN_VERSION] .."
    wget -qO $BITCOIN_TARBALL "$BITCOIN_URL"
    wget -qO bitcoin.asc "$BITCOIN_ASC_URL"

    # Extract the tarball's checksum from the released .asc and verify it
    echo "Verifying release .."
    grep $BITCOIN_TARBALL bitcoin.asc | tee SHA256SUMS.asc
    sha256sum -c SHA256SUMS.asc

    # Extract
    echo "Extracting binaries .."
    tar -xzvf $BITCOIN_TARBALL $BITCOIN_DIST_BINARIES_DIRECTORY/ --strip-components=1

    # Cleanup
    echo "Cleaning up .."
    rm $BITCOIN_TARBALL
    rm bitcoin.asc
    rm SHA256SUMS.asc
    rm $INSTALL_DIRECTORY/bin/bitcoin-qt
    rm $INSTALL_DIRECTORY/bin/test_bitcoin

    # Update permissions
    echo "Updating permissions .."
    chown -R root:root $INSTALL_DIRECTORY
    chmod -R 0755 $INSTALL_DIRECTORY

    # Install executables in the local bin folder and symlink the daemon
    install -m 0755 -o root -g root -t /usr/local/bin $INSTALL_DIRECTORY/bin/*
    if [[ -f /usr/bin/bitcoind ]]; then
        rm /usr/bin/bitcoind
    fi
    ln -sf /usr/local/bin/bitcoind /usr/bin/bitcoind
}

# Service setup (conf and service files)
function setup_service() {
    # Install default config file if no file exists
    if [[ ! -f $CONFIG_DIRECTORY/bitcoin.conf ]]; then
        echo "Installing default config"
        wget -qO bitcoin.conf "$CONFIG_FILE_URL"
        if [[ ! -d $CONFIG_DIRECTORY ]]; then
            echo "Creating config directory: $CONFIG_DIRECTORY"
            mkdir $CONFIG_DIRECTORY
        fi

        # Deploy default config
        mv bitcoin.conf $CONFIG_DIRECTORY/
    fi

    # Install default service unit if one is not present
    if [[ ! -f $SERVICE_DIRECTORY/bitcoind.service ]]; then
        echo "Installing systemd service unit .."
        wget -qO bitcoind.service "$SERVICE_FILE_URL"
        if [[ ! -d $SERVICE_DIRECTORY ]]; then
            echo "Creating service directory: $SERVICE_DIRECTORY"
            mkdir $SERVICE_DIRECTORY
        fi

        # Copy and reload service unit
        mv bitcoind.service $SERVICE_DIRECTORY/
        systemctl daemon-reload
    fi

    # Enable installed service
    echo "Enabling bitcoind service unit .."    
    systemctl enable bitcoind.service
}

###############################################################################
# EXECUTION
###############################################################################

# Prep
sanity_checks
create_user
create_dirs

# Install
pushd $INSTALL_DIRECTORY
download_and_install
setup_service
echo "Installation COMPLETE! Start with 'systemctl start bitcoind'"
popd