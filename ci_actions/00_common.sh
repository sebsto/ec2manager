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

echo "Default region: $REGION"
echo "AWS CLI       : $AWS_CLI"
echo "Code directory: $CODE_DIR"
echo "Home directory: $HOME"