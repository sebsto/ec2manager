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

KEYCHAIN_PASSWORD=Passw0rd
KEYCHAIN_NAME=dev.keychain
security unlock-keychain -p $KEYCHAIN_PASSWORD $KEYCHAIN_NAME

pushd $HOME/amplify-ios-getting-started/code

WORKSPACE="getting started.xcworkspace"
SCHEME="getting started"
PHONE_MODEL="iPhone 14 Pro"
IOS_VERSION="16.2"

xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME"       \
    -destination platform="iOS Simulator",name="${PHONE_MODEL}",OS=${IOS_VERSION}  | xcbeautify

popd