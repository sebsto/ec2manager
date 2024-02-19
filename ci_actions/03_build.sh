#!/bin/sh
set -e 
set -o pipefail

. ci_actions/00_common.sh

echo "Changing to code directory at $CODE_DIR"
pushd $CODE_DIR

KEYCHAIN_PASSWORD=Passw0rd
KEYCHAIN_NAME=dev.keychain

PROJECT="EC2Manager.xcodeproj"
SCHEME="EC2Manager"
CONFIGURATION="Release"
BUILD_PATH="./build-release"
ARCHIVE_PATH="$BUILD_PATH/EC2Manager.xcarchive"

# Increase Build Number
# https://rderik.com/blog/automating-build-and-testflight-upload-for-simple-ios-apps/

BUILD_NUMBER=`date +%Y%m%d%H%M%S`
echo "Updated build number is " $BUILD_NUMBER
plutil -replace CFBundleVersion -string $BUILD_NUMBER "./EC2Manager/Info.plist"

security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME

xcodebuild clean archive                    \
           -project "$PROJECT"          \
           -scheme "$SCHEME"                \
           -archivePath "$ARCHIVE_PATH"     \
           -derivedDataPath "${BUILD_PATH}" \
           -configuration "$CONFIGURATION"   | $BREW_PATH/xcbeautify

popd