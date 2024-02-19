#!/bin/sh
set -e 
set -o pipefail

# Thanks to 
# https://medium.com/appssemble/a-guide-to-writing-your-own-ios-ci-cd-integration-script-186be1b99575

arch_name="$(uname -m)"
if [ ${arch_name} = "arm64" ]; then 
    AWS_CLI=/opt/homebrew/bin/aws
else
    AWS_CLI=/usr/local/bin/aws 
fi

AMPLIFY_CLI=$HOME/.amplify/bin/amplify
REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/region/)
HOME=/Users/ec2-user
export LANG=en_US.UTF-8

# pushd $HOME 
# if [ -d amplify-ios-getting-started ]; then
#     rm -rf amplify-ios-getting-started
# fi
# git clone https://github.com/sebsto/amplify-ios-getting-started.git
# popd

CODE_DIR=$HOME/amplify-ios-getting-started/code
echo "Changing to code directory at $CODE_DIR"
pushd $CODE_DIR

echo "Pulling amplify environment"

AMPLIFY_APPID_SECRET=amplify-app-id
AMPLIFY_PROJECT_NAME_SECRET=amplify-project-name
AMPLIFY_ENV_SECRET=amplify-environment
AMPLIFY_APPID=$($AWS_CLI --region $REGION secretsmanager get-secret-value --secret-id $AMPLIFY_APPID_SECRET --query SecretString --output text)
AMPLIFY_PROJECT_NAME=$($AWS_CLI --region $REGION secretsmanager get-secret-value --secret-id $AMPLIFY_PROJECT_NAME_SECRET --query SecretString --output text)
AMPLIFY_ENV=$($AWS_CLI --region $REGION secretsmanager get-secret-value --secret-id $AMPLIFY_ENV_SECRET --query SecretString --output text)  


AWSCLOUDFORMATIONCONFIG="{\
\"configLevel\":\"general\",\
\"useProfile\":true,\
\"profileName\":\"default\"\
}"

AMPLIFY="{\
\"projectName\":\"$AMPLIFY_PROJECT_NAME\",\
\"appId\":\"$AMPLIFY_APPID\",\
\"envName\":\"$AMPLIFY_ENV\",\
\"defaultEditor\":\"code\"\
}"
FRONTEND="{\
\"frontend\":\"ios\"
}"
PROVIDERS="{\
\"awscloudformation\":$AWSCLOUDFORMATIONCONFIG\
}"


$AMPLIFY_CLI pull \
--amplify $AMPLIFY \
--frontend $FRONTEND \
--providers $PROVIDERS \
--yes --region $DEFAULT_REGION


echo "Generate code for application models"
$AMPLIFY_CLI codegen models 
# Increase Build Number
# https://rderik.com/blog/automating-build-and-testflight-upload-for-simple-ios-apps/

BUILD_NUMBER=`date +%Y%m%d%H%M%S`
plutil -replace CFBundleVersion -string $BUILD_NUMBER "./getting started/Info.plist"

popd

# security find-identity -v -p codesigning  