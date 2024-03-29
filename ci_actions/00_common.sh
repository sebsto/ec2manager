#!/bin/sh

arch_name="$(uname -m)"
if [ ${arch_name} = "arm64" ]; then 
    export BREW_PATH=/opt/homebrew/bin
    export AWS_CLI=$BREW_PATH/aws
else
    export BREW_PATH=/usr/local/bin
    export AWS_CLI=$BREW_PATH/aws
fi

TOKEN=$(curl -s -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -X PUT 'http://169.254.169.254/latest/api/token')
export REGION=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" 'http://169.254.169.254/latest/meta-data/placement/region')
export LANG=en_US.UTF-8

export HOME=/Users/ec2-user
export CODE_DIR=$HOME/ec2manager # default value
if [ ! -z ${GITHUB_ACTION} ]; then # we are running from a github runner
    export CODE_DIR=$GITHUB_WORKSPACE
fi
if [ ! -z ${CI_BUILDS_DIR} ]; then # we are running from a gitlab runner
    export CODE_DIR=$CI_PROJECT_DIR
fi
if [ ! -z ${CIRCLE_WORKING_DIRECTORY} ]; then # we are running from a gitlab runner
    export CODE_DIR=$CIRCLE_WORKING_DIRECTORY
fi

KEYCHAIN_PASSWORD=Passw0rd
KEYCHAIN_NAME=dev.keychain
PROJECT="EC2Manager.xcodeproj"
SCHEME="EC2Manager"
BUILD_PATH="./build-release"
ARCHIVE_PATH="$BUILD_PATH/EC2Manager.xcarchive"
PHONE_MODEL="iPhone 15 Pro"
IOS_VERSION="17.2"

echo "Default region: $REGION"
echo "AWS CLI       : $AWS_CLI"
echo "Code directory: $CODE_DIR"
echo "Home directory: $HOME"