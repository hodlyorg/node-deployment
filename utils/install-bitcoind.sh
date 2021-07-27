#!/bin/bash

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
CONFIG_DIRECTORY="/etc/bitcoind"
LOG_DIRECTORY="/var/log/bitcoind"
RUN_DIRECTORY="/run/bitcoind"
SHELL_ACCESS="/usr/sbin/nologin"

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

    fi
else
    if [ ! getent group $TARGET_GROUP ]; then
        echo "ERROR: User [$TARGET_USER] exists already, but the group [$TARGET_GROUP] cannot be found"
        exit
    else 
        echo "Target user and group exist already .."
    fi
fi

# Extract and cleanup
echo "Installing .."
tar -xzvf $BITCOIN_TARBALL $BITCOIN_DIST_BINARIES_DIRECTORY/ --strip-components=1
rm $BITCOIN_TARBALL
rm $INSTALL_DIRECTORY/bin/bitcoin-qt

# Install executables in the local bin folder
install -m 0755 -o root -g root -t /usr/local/bin $INSTALL_DIRECTORY/bin/*

# Pop directory stack
echo "Installation COMPLETE!"
popd