#!/bin/bash

# Privileges check
if [ $EUID -ne 0 ]
  then echo "Please run as root"
  exit
fi

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

# Resources
SERVICE_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/init/bitcoind.service"
CONFIG_FILE_URL="https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/examples/bitcoin.conf"

# Enable pipefail and print command trace to console
set -ex

# Make sure the system is up to date
echo "Updating System .."
apt-get update
apt-get install -y --no-install-recommends ca-certificates dirmngr wget

# Create install directory if needed
if [ ! -d $INSTALL_DIRECTORY ]; then
    echo "Creating target directory: $INSTALL_DIRECTORY"
    mkdir $INSTALL_DIRECTORY
fi

# Move directory stack to the target install path
pushd $INSTALL_DIRECTORY

# Download Tarball and Checksums
echo "Downloading release [$BITCOIN_VERSION] .."
wget -qO $BITCOIN_TARBALL "$BITCOIN_URL"
wget -qO bitcoin.asc "$BITCOIN_ASC_URL"

# Extract the tarball's checksum from the released .asc and verify it
echo "Verifying release .."
grep $BITCOIN_TARBALL bitcoin.asc | tee SHA256SUMS.asc
sha256sum -c SHA256SUMS.asc

# User setup
echo "Setting up user and group .."
if [ ! getent passwd $TARGET_USER ]; then
    if [ ! getent group $TARGET_GROUP ]; then
        echo "Creating user [$TARGET_USER] and group [$TARGET_GROUP] .."
        useradd -d $DATA_DIRECTORY -s $SHELL_ACCESS $TARGET_USER
    fi
else
    if [ ! getent group $TARGET_GROUP ]; then
        echo "ERROR: User [$TARGET_USER] exists already, but the group [$TARGET_GROUP] cannot be found"
        exit
    else 
        echo "Target user and group exist already, nothing to do .."
    fi
fi

# Extract
echo "Installing binaries .."
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
if [ -f /usr/bin/bitcoind ]; then
    rm /usr/bin/bitcoind
fi
ln -s /usr/local/bin/bitcoind /usr/bin/bitcoind

# Create directories
if [ ! -d $CONFIG_DIRECTORY ]; then
    echo "Creating config directory: $CONFIG_DIRECTORY"
    mkdir $CONFIG_DIRECTORY
fi

if [ ! -d $RUN_DIRECTORY ]; then
    echo "Creating run directory: $RUN_DIRECTORY"
    mkdir $RUN_DIRECTORY
    chown $TARGET_USER:$TARGET_GROUP $RUN_DIRECTORY
fi

# Install default config
echo "Installing default config"
wget -qO bitcoin.conf "$CONFIG_FILE_URL"
if [ ! -d $CONFIG_DIRECTORY ]; then
    echo "Creating config directory: $CONFIG_DIRECTORY"
    mkdir $CONFIG_DIRECTORY
fi
mv bitcoin.conf $CONFIG_DIRECTORY/

# Install default service
echo "Installing systemd service unit .."
wget -qO bitcoind.service "$SERVICE_FILE_URL"
if [ ! -d $SERVICE_DIRECTORY ]; then
    echo "Creating service directory: $SERVICE_DIRECTORY"
    mkdir $SERVICE_DIRECTORY
fi
mv bitcoind.service $SERVICE_DIRECTORY/
echo "Enabling bitcoind service unit .."
systemctl enable bitcoind.service

# Pop directory stack
echo "Installation COMPLETE!"
popd