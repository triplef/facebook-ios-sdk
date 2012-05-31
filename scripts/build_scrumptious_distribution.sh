#!/bin/sh
#
# Copyright 2004-present Facebook. All Rights Reserved.
#
# This script builds the Scrumptious sample app for internal distribution.
# It requires a provisioning profile UUID, build number, and file name for
# the final package.

. ${FB_SDK_SCRIPT:-$(dirname $0)}/common.sh

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 BUILD_NUMBER PRODUCT_NAME PROFILE_UUID CODE_SIGN_IDENTITY"
    echo "  BUILD_NUMBER         build number to place in bundle"
    echo "  PRODUCT_NAME         name of the final .ipa package (e.g., Scrumptious.ipa)"
    echo "  PROFILE_UUID         UUID of the provisioning profile"
    echo "  CODE_SIGN_IDENTITY   name of the code sign identity"
    die 'Invalid arguments'
fi

BUILD_NUMBER="$1"
FINAL_PRODUCT_NAME="$2"
PROFILE_UUID="$3"
CODE_SIGN_IDENTITY="$4"

test -x "$XCODEBUILD" || die 'Could not find xcodebuild in $PATH'

# -----------------------------------------------------------------------------
echo 'Building Scrumptious (Distribution).'

# -----------------------------------------------------------------------------
# Call out to build .framework
#
#if is_outermost_build; then
# TODO reenable
#  . $FB_SDK_SCRIPT/build_framework.sh
#fi

# -----------------------------------------------------------------------------
# Build Scrumptious
#
PRODUCT_NAME="Scrumptious"
CONFIGURATION="Release"
SDK="iphoneos"
APP_NAME="$PRODUCT_NAME".app

OUTPUT_DIR=`mktemp -d -t ${PRODUCT_NAME}-inhouse`
RESULTS_DIR="$OUTPUT_DIR"/"$CONFIGURATION"-"$SDK"

cd $FB_SDK_SAMPLES/Scrumptious

$XCODEBUILD \
  -alltargets \
  -sdk "$SDK" \
  -configuration "$CONFIGURATION" \
  -arch "armv7" \
  SYMROOT="$OUTPUT_DIR" \
  OBJROOT="$OUTPUT_DIR" \
  CURRENT_PROJECT_VERSION="$FB_SDK_VERSION_FULL" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  PROVISIONING_PROFILE="$PROFILE_UUID" \
  FB_BUNDLE_VERSION="$BUILD_NUMBER" \
  clean build \
  >>$FB_SDK_BUILD_LOG 2>&1 \
  || die "XCode build failed for Scrumptious (Distribution)."

# -----------------------------------------------------------------------------
# Build .ipa package
#
PACKAGE_DIR=`mktemp -d -t ${PRODUCT_NAME}-inhouse-pkg`

echo Building Package
pushd "$PACKAGE_DIR" >/dev/null
PAYLOAD_DIR="Payload"
mkdir "$PAYLOAD_DIR"
cp -a "$RESULTS_DIR"/"$APP_NAME" "$PAYLOAD_DIR"
rm -f "$FINAL_PRODUCT_NAME"
zip -y -r "$FINAL_PRODUCT_NAME" "$PAYLOAD_DIR" >>$FB_SDK_BUILD_LOG 2>&1
echo ...Package at: "$PACKAGE_DIR"/"$FINAL_PRODUCT_NAME"


# -----------------------------------------------------------------------------
# Validate .ipa package
#
echo Validating Package

# Apple's Validation tool exits with error code 0 even on error, so we have to search the output.
VALIDATION_TOOL="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/Validation"
VALIDATION_RESULT=`"$VALIDATION_TOOL" -verbose -errors "$FINAL_PRODUCT_NAME"`
if [[ "$VALIDATION_RESULT" == *error:* ]]; then
    echo "Validation failed: $VALIDATION_RESULT"
    exit 1
fi

popd >/dev/null

# -----------------------------------------------------------------------------
# Archive the build and .dSYM symbols
echo Archiving build and symbols
BUILD_ARCHIVE_DIR=~/iossdkarchive/"$PRODUCT_NAME"/"$BUILD_NUMBER"
mkdir -p "$BUILD_ARCHIVE_DIR"

pushd "$RESULTS_DIR" >/dev/null

ARCHIVE_PATH="$BUILD_ARCHIVE_DIR"/Archive-"$BUILD_NUMBER".zip
zip -y -r "$ARCHIVE_PATH" "$APP_NAME" "$APP_NAME".dSYM \
  >>$FB_SDK_BUILD_LOG 2>&1
echo ...Archive at: "$ARCHIVE_PATH"

popd >/dev/null

# -----------------------------------------------------------------------------
# Done
#
common_success