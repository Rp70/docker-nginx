#!/usr/bin/env bash
set -e

TARGET_USER='nginx'
# Change uid and gid of user $TARGET_USER to match current dir's owner
if [ "$MAP_WWW_UID" != "no" ]; then
    if [ ! -d "$MAP_WWW_UID" ]; then
        MAP_WWW_UID=$PWD
    fi

    uid=$(stat -c '%u' "$MAP_WWW_UID")
    gid=$(stat -c '%g' "$MAP_WWW_UID")

    usermod -u $uid $TARGET_USER 2> /dev/null && {
      groupmod -g $gid $TARGET_USER 2> /dev/null || usermod -a -G $gid $TARGET_USER
    }
fi
