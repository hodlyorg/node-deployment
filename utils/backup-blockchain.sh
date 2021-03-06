#!/bin/bash
BITCOIND_DATA_BACKUP_ROOT=$1
BITCOIND_DATA_SOURCE_ROOT="/var/lib/bitcoind/"
SERVICE_NAME="bitcoind"
TOOL="rsync"
TOOL_PARAMS="-avh --delete --progress $BITCOIND_DATA_SOURCE_ROOT $BITCOIND_DATA_BACKUP_ROOT"

# Check if required tooling is available
if [[ $( command -v $TOOL ) == "" ]]; then
    echo "ERROR: A required command line tool is missing: $TOOL"
    exit
fi

# Check if the bitcoin service is running
if [[ $( pidof $SERVICE_NAME ) -ne 0 ]]; then
    echo "ERROR: The [$SERVICE_NAME] is running, please stop the service before executing the backup"
    exit
fi

# Check source
if [[ ! -d "$BITCOIND_DATA_SOURCE_ROOT" ]];
then
    echo "ERROR: Source path [$BITCOIND_DATA_SOURCE_ROOT] must be an existing directory"
    exit
fi

if [[ "$BITCOIND_DATA_SOURCE_ROOT" != */ ]];
then 
    echo "ERROR: Source path [$BITCOIND_DATA_SOURCE_ROOT] must target the contents of a directory (end with '/')"
    exit
fi

# Check destination
if [[ ! -d "$BITCOIND_DATA_BACKUP_ROOT" ]];
then
    echo "ERROR: Destination path [$BITCOIND_DATA_BACKUP_ROOT] must be an existing directory"
    exit
fi

if [[ "$BITCOIND_DATA_BACKUP_ROOT" != */ ]];
then
    echo "ERROR: Destination path [$BITCOIND_DATA_BACKUP_ROOT] must target the contents of a directory (end with '/')"
    exit
fi

# Initiate backup sync
echo "Syncing contents from $BITCOIND_DATA_SOURCE_ROOT to $BITCOIND_DATA_BACKUP_ROOT"
$TOOL $TOOL_PARAMS
