#!/bin/sh
set -e 
set -o pipefail

. ci_actions/00_common.sh

# search for amplify 
AMPLIFY_STANDALONE=/Users/ec2-user/.amplify/bin/amplify
AMPLIFY_BREW=/opt/homebrew/bin/amplify
if [ -f $AMPLIFY_STANDALONE ]; then
	AMPLIFY_CLI=$AMPLIFY_STANDALONE
elif [ -f $AMPLIFY_BREW ]; then
	AMPLIFY_CLI=$AMPLIFY_BREW
else
	echo "🛑 Amplify CLI not found"
	exit 1
fi

echo "Using amplify at $AMPLIFY_CLI"
echo "Changing to code directory at $CODE_DIR"
pushd $CODE_DIR

echo "Pulling amplify environment"

AMPLIFY_APPID_SECRET=ec2manager-amplify-app-id
AMPLIFY_PROJECT_NAME_SECRET=ec2manager-amplify-project-name
AMPLIFY_ENV_SECRET=ec2manager-amplify-environment
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

# the region where the backend is deployed
BACKEND_REGION=eu-central-1 

# double command execution, this is a workaround for issue https://github.com/aws-amplify/amplify-cli/issues/13201
export AWS_REGION=$BACKEND_REGION

$AMPLIFY_CLI pull \
--amplify $AMPLIFY \
--frontend $FRONTEND \
--providers $PROVIDERS \
--yes || \
echo "First amplify pull failed, applying workaround for Amplify CLI Issue # 13201" && \
mkdir -p $CODE_DIR/amplify/generated/models && \
$AMPLIFY_CLI pull \
--amplify $AMPLIFY \
--frontend $FRONTEND \
--providers $PROVIDERS \
--yes

export AWS_REGION=

popd
