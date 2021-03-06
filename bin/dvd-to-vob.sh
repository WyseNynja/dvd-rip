#!/bin/bash
# rip a DVD to VOBs
#
# install http://www.videolan.org/developers/libdvdcss.html
#
# 'udevadm info -q env -n /dev/sr0' to see all env vars
#
# TODO: put things in proper functions like vob-to-handbrake.sh

set -eo pipefail
shopt -s nullglob

echo "===="
uptime

DVD_RIP_BIN_DIR="$(cd "$(dirname "$0")" && pwd -P)"

VOB_D=${1:?}
echo "VOB_D=$VOB_D"

MOVIE_D=${2:?}
echo "MOVIE_D=$MOVIE_D"

[ -z "$DEVNAME" ] && DEVNAME="/dev/sr0"
echo "DEVNAME=$DEVNAME"
mount "$DEVNAME"

SRC_D=$(df "$DEVNAME" | tail -1 | awk '{ printf $6 }')
if [ -z "$SRC_D" ]; then
    echo "ERROR: Mounting error for $DEVNAME"
    eject "$DEVNAME"
    exit 10
fi

# set all the env variables here. (happens when not entering through udev)
if [ -z "$ID_FS_LABEL" ] || [ -z "$ID_FS_UUID" ]; then
    echo "Exporting device properties..."
    eval "$(udevadm info --name="$DEVNAME" --query property --export)"
fi

# sometimes ID_FS_LABEL is useless things like "DVD_VIDEO" or "SONY"
# and sometimes sequels have the same name on the DVD
DVD_NAME="${ID_FS_LABEL}_${ID_FS_UUID}"
if [ -z "$ID_FS_LABEL" ] || [ -z "$ID_FS_UUID" ]; then
    echo "ERROR: Both ID_FS_LABEL and ID_FS_UUID are required: $DVD_NAME"
    eject "$DEVNAME"
    exit 11
fi
echo "DVD_NAME=$DVD_NAME"

if [ -d "$VOB_D/$DVD_NAME" ]; then
    echo "Movie '$DVD_NAME' already exists. Nothing to do"
    eject "$DEVNAME"
    exit 0
fi

if [ -d "$VOB_D/.$DVD_NAME" ]; then
    echo "WARNING: Cleaning up previous workdir..."
    # TODO: can we make vobcopy smart enough to reuse it?
    rm -rf "$VOB_D/.$DVD_NAME"
fi

mkdir -p "$VOB_D/.$DVD_NAME"

# TODO: timeout in case the copy gets stuck
echo "Starting vobcopy to '$VOB_D/.$DVD_NAME'..."
vobcopy \
    --input-dir "$SRC_D" \
    --large-file \
    --name "$DVD_NAME" \
    --output-dir "$VOB_D/.$DVD_NAME" \
&& EXIT_CODE=0 || EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "FAILED with exit code $EXIT_CODE"
    eject "$DEVNAME"
    exit 12
fi

mv "$VOB_D/.$DVD_NAME" "$VOB_D/$DVD_NAME"
echo "SUCCESS! $VOB_D/$DVD_NAME"

eject "$DEVNAME"

echo "Scheduling transcode..."
# TODO: log the command we are about to run
# TODO: log the command to a file instead of mail
echo "\"$DVD_RIP_BIN_DIR/vob-to-handbrake.sh\" \"$VOB_D/$DVD_NAME\" \"$MOVIE_D\" \"$DVD_NAME.mkv\" >>\"/var/log/dvd-rip/vob-to-handbrake.$DVD_NAME.log\" 2>&1" | tee >(batch)

echo "SUCCESS for $DVD_NAME!"
