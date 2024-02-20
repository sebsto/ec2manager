#!/bin/sh
set -e 
set -o pipefail

. ci_actions/00_common.sh

echo "Changing to code directory at $CODE_DIR"
pushd $CODE_DIR

CONFIGURATION="Release"

# Increase Build Number
# Does not work here because Xcode generates the Info.plist file dynamically

# https://rderik.com/blog/automating-build-and-testflight-upload-for-simple-ios-apps/
#BUILD_NUMBER=`date +%Y%m%d%H%M%S`
#echo "Updated build number is " $BUILD_NUMBER
#plutil -replace CFBundleVersion -string $BUILD_NUMBER "./EC2Manager/Info.plist"

# https://developer.apple.com/library/archive/qa/qa1827/_index.html
# agvtool next-version -all

security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME

xcodebuild clean archive                    \
           -project "$PROJECT"              \
           -scheme "$SCHEME"                \
           -archivePath "$ARCHIVE_PATH"     \
           -derivedDataPath "${BUILD_PATH}" \
           -configuration "$CONFIGURATION"  \
           -destination platform="iOS Simulator",name="${PHONE_MODEL}",OS=${IOS_VERSION} | $BREW_PATH/xcbeautify

# Update build number in the archive. Each build must have a unique number before uploading to AppStore connect
BUILD_NUMBER=`date +%Y%m%d%H%M%S`
echo "Updated build number is " $BUILD_NUMBER
plutil -replace ApplicationProperties.CFBundleVersion -string $BUILD_NUMBER "build-release/EC2Manager.xcarchive/Info.plist"

popd
