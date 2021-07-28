#!/bin/bash
SOURCEDIR=$1
DESTDIR=$2
TOOL="rsync"
TOOL_PARAMS="--ignore-existing --delete -hvrPt $SOURCEDIR $DESTDIR"
SERVICE_NAME="bitcoind"

# Check if required tooling is available
if [[ ! command -v $TOOL &> /dev/null ]]; then
    echo "ERROR: A required command line tool is missing: $TOOL"
    exit
fi

# Check if the bitcoin service is running
if [[ $( pidof $SERVICE_NAME ) -ne 0 ]]; then
    echo "ERROR: The [$SERVICE_NAME] is running, please stop the service before executing the backup"
    exit
fi

# Check source
if [[ ! -d "$SOURCEDIR" ]];
then
    echo "ERROR: Source path [$SOURCEDIR] must target an existing directory"
    exit
fi

# Check destination
if [[ ! -d "$DESTDIR" ]];
then
    echo "ERROR: Destination path [$DESTDIR] must target an existing directory"
    exit
fi

# Initiate backup sync
echo "Syncing contents from $SOURCEDIR to $DESTDIR"
$TOOL $TOOL_PARAMS