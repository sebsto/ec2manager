#!/bin/sh
set -e 
set -o pipefail

. ci_actions/00_common.sh

echo "Changing to code directory at $CODE_DIR"
pushd $CODE_DIR

xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME"       \
    -destination platform="iOS Simulator",name="${PHONE_MODEL}",OS=${IOS_VERSION}  | $BREW_PATH/xcbeautify

popd
