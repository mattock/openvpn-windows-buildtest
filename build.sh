#!/bin/bash
#
# The main script

# Refuse to start if another build is in progress
ps a|grep -v grep|grep build\-snapshot > /dev/null 2>&1 
if [ $? -eq 0 ]; then
    exit 0
fi

# Load base configuration
. ./vars

# Load extra configuration if asked to. This is what enables us to build both 
# Git "master" and "release/2.3" branches from the same directory.
if [ "$1" != "" ] && [ -r "$1" ]; then
        . $1
fi

# Create the temp dir if it's missing
if ! [ -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR"
fi

# Update the last run timestamp
touch "$TEMP_DIR/last_run"

# Clone openvpn
rm -rf "$TEMP_DIR/openvpn"
git clone $OPENVPN_GIT_URL --branch $OPENVPN_BRANCH "$TEMP_DIR/openvpn" > /dev/null 2>&1

# Get latest commit id
cd "$TEMP_DIR/openvpn"
LATEST_COMMIT=`git log|head -n 1|cut -d " " -f 2`
LATEST_COMMIT_ABBREV=${LATEST_COMMIT:0:10}

# Check if this is the first run, in which case we add a fake latest_commit file 
# to trigger a build
if ! [ -f "$TEMP_DIR/latest_commit" ]; then
    echo "placeholder" > "$TEMP_DIR/latest_commit"
fi

# Compare latest commit to previous latest commit; if commit ids don't match 
# then build
echo "$LATEST_COMMIT" > "$TEMP_DIR/latest_commit.new"
diff "$TEMP_DIR/latest_commit.new" "$TEMP_DIR/latest_commit" > /dev/null 2>&1

if [ $? -ne 0 ] || [ "$FORCE" = "true" ]; then

    # We don't want openvpn-build to send logs in non-English languages
    export LC_ALL=C
    export LANG=C

    # Refetch openvpn-build
    rm -rf "$BASE_DIR/openvpn-build"
    git clone -b $OPENVPN_BUILD_BRANCH $OPENVPN_BUILD_GIT_URL "$BASE_DIR/openvpn-build" > /dev/null 2>&1

    cd "$WINDOWS_NSIS_DIR"
    EXTRA_OPENVPN_CONFIG="$EXTRA_OPENVPN_CONFIG" OPENVPN_BRANCH="$OPENVPN_BRANCH" OPENVPN_VERSION="$OPENVPN_VERSION" OPENVPN_GUI_VERSION="$OPENVPN_GUI_VERSION" OPENVPN_GUI_URL="$OPENVPN_GUI_URL" MAKEOPTS="-j1" ./build-snapshot --sign --sign-pkcs12="$CERT_FILE" --sign-pkcs12-pass="$CERT_PASS" --sign-timestamp="$SIGN_TIMESTAMP_URL" > "$LOG" 2>&1

    if [ $? -ne 0 ]; then
        tail -n 100 "$LOG" > "$LOG_TAIL"
        cat "$LOG_TAIL"|mail -s "ERROR: build-snapshot FAILED for commit $LATEST_COMMIT_ABBREV on branch $OPENVPN_BRANCH" $EMAIL
    else
        tail -n 100 "$LOG" > "$LOG_TAIL"
        cat "$LOG_TAIL"|mail -s "NOTICE: build-snapshot succeeded for commit $LATEST_COMMIT_ABBREV on branch $OPENVPN_BRANCH" $EMAIL

        # Publish the package we just built
        TIMESTAMP=`date +'%Y%m%d%H%M%S'`

        # Remove slashes from the branch name (e.g. "release/2.3")
        BRANCH=`echo "$OPENVPN_BRANCH"|tr "/" "-"`

        NEW_BASENAME="openvpn-install-$BRANCH-$TIMESTAMP-$LATEST_COMMIT_ABBREV"

        if [ "$BRANCH" = "master" ]; then
            INSTALLER_COMBINED=`ls openvpn-install-2.*-I???.exe`
            scp $INSTALLER_COMBINED $WEBSERVER:$WEBSERVER_DIR/$NEW_BASENAME.exe

        elif [ "$BRANCH" = "release-2.3" ]; then
            INSTALLER_32=`ls openvpn-install-2.*-i686.exe`
            INSTALLER_64=`ls openvpn-install-2.*-x86_64.exe`
            scp $INSTALLER_32 $WEBSERVER:$WEBSERVER_DIR/$NEW_BASENAME-i686.exe
            scp $INSTALLER_64 $WEBSERVER:$WEBSERVER_DIR/$NEW_BASENAME-x86_64.exe
        fi
    fi

else
    exit 0
fi

# Update latest commit file to prevent further builds until a fix is committed
echo "$LATEST_COMMIT" > "$TEMP_DIR/latest_commit"
