#!/bin/sh
set -e 
set -o pipefail

arch_name="$(uname -m)"
if [ ${arch_name} = "arm64" ]; then 
    AWS_CLI=/opt/homebrew/bin/aws
else
    AWS_CLI=/usr/local/bin/aws 
fi
REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/region/)
HOME=/Users/ec2-user

pushd $HOME/EC2Manager

KEYCHAIN_PASSWORD=Passw0rd
KEYCHAIN_NAME=dev.keychain

WORKSPACE="EC2Manager.xcworkspace"
SCHEME="EC2Manager"
CONFIGURATION="Release"
BUILD_PATH="./build-release"
ARCHIVE_PATH="$BUILD_PATH/EC2Manager.xcarchive"

security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME

xcodebuild clean archive                    \
           -workspace "$WORKSPACE"          \
           -scheme "$SCHEME"                \
           -archivePath "$ARCHIVE_PATH"     \
           -derivedDataPath "${BUILD_PATH}" \
           -configuration "$CONFIGURATION"  | xcbeautify

popd
