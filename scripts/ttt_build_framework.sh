#!/bin/sh
#
# This script builds the FacebookSDK.framework including changes from taptaptap.
# Based on facebook's build script, but using simple vanilla xcodebuild.

BUILDCONFIGURATION=Release

# Set up paths
if [ -z "$FB_SDK_SCRIPT" ]; then
  # ---------------------------------------------------------------------------
  # Set up paths
  #

  # The directory containing this script
  # We need to go there and use pwd so these are all absolute paths
  pushd "$(dirname $BASH_SOURCE[0])" >/dev/null
  FB_SDK_SCRIPT=$(pwd)
  popd >/dev/null

  # The root directory where the Facebook SDK for iOS is cloned
  FB_SDK_ROOT=$(dirname "$FB_SDK_SCRIPT")

  # Path to source files for Facebook SDK
  FB_SDK_SRC=$FB_SDK_ROOT/src

  # The directory where the target is built
  FB_SDK_BUILD=$FB_SDK_ROOT/build
  FB_SDK_BUILD_LOG=$FB_SDK_BUILD/build.log

  # The name of the Facebook SDK for iOS
  FB_SDK_BINARY_NAME=FacebookSDK

  # The name of the Facebook SDK for iOS framework
  FB_SDK_FRAMEWORK_NAME=${FB_SDK_BINARY_NAME}.framework

  # The path to the built Facebook SDK for iOS .framework
  FB_SDK_FRAMEWORK=$FB_SDK_BUILD/$FB_SDK_FRAMEWORK_NAME

  # Extract the SDK version from FacebookSDK.h
  FB_SDK_VERSION_RAW=$(sed -n 's/.*FB_IOS_SDK_VERSION_STRING @\"\(.*\)\"/\1/p' "${FB_SDK_SRC}"/FacebookSDK.h)
  FB_SDK_VERSION_MAJOR=$(echo $FB_SDK_VERSION_RAW | awk -F'.' '{print $1}')
  FB_SDK_VERSION_MINOR=$(echo $FB_SDK_VERSION_RAW | awk -F'.' '{print $2}')
  FB_SDK_VERSION_REVISION=$(echo $FB_SDK_VERSION_RAW | awk -F'.' '{print $3}')
  FB_SDK_VERSION_MAJOR=${FB_SDK_VERSION_MAJOR:-0}
  FB_SDK_VERSION_MINOR=${FB_SDK_VERSION_MINOR:-0}
  FB_SDK_VERSION_REVISION=${FB_SDK_VERSION_REVISION:-0}
  FB_SDK_VERSION=$FB_SDK_VERSION_MAJOR.$FB_SDK_VERSION_MINOR.$FB_SDK_VERSION_REVISION
  FB_SDK_VERSION_SHORT=$(echo $FB_SDK_VERSION | sed 's/\.0$//')
fi

FB_SDK_UNIVERSAL_BINARY=$FB_SDK_BUILD/${BUILDCONFIGURATION}-universal/$FB_SDK_BINARY_NAME

# Call this when there is an error.  This does not return.
function die() {
  echo ""
  echo "FATAL: $*" >&2
  show_summary
  exit 1
}

# Assuming submodules are up to date.

# Compile
mkdir -p ${FB_SDK_BUILD}
for sdk in iphoneos iphonesimulator
do
	xcodebuild -project ${FB_SDK_SRC}/facebook-ios-sdk.xcodeproj -scheme facebook-ios-sdk -sdk ${sdk} -configuration ${BUILDCONFIGURATION} ONLY_ACTIVE_ARCH=NO RUN_CLANG_STATIC_ANALYZER=NO SYMROOT=${FB_SDK_BUILD} clean build
done

# -----------------------------------------------------------------------------
# Merge lib files for different platforms into universal binary
#
echo "Building $FB_SDK_BINARY_NAME library using lipo."

mkdir -p "$(dirname "$FB_SDK_UNIVERSAL_BINARY")"

lipo \
  -create \
    "$FB_SDK_BUILD/${BUILDCONFIGURATION}-iphonesimulator/libfacebook_ios_sdk.a" \
    "$FB_SDK_BUILD/${BUILDCONFIGURATION}-iphoneos/libfacebook_ios_sdk.a" \
  -output "$FB_SDK_UNIVERSAL_BINARY" \
  || die "lipo failed - could not create universal static library"

# -----------------------------------------------------------------------------
# Build .framework out of binaries
#
echo "Building $FB_SDK_FRAMEWORK_NAME."

\rm -rf "$FB_SDK_FRAMEWORK"
mkdir "$FB_SDK_FRAMEWORK" \
  || die "Could not create directory $FB_SDK_FRAMEWORK"
mkdir "$FB_SDK_FRAMEWORK/Versions"
mkdir "$FB_SDK_FRAMEWORK/Versions/A"
mkdir "$FB_SDK_FRAMEWORK/Versions/A/Headers"
mkdir "$FB_SDK_FRAMEWORK/Versions/A/DeprecatedHeaders"
mkdir "$FB_SDK_FRAMEWORK/Versions/A/Resources"

\cp \
  "$FB_SDK_BUILD/${BUILDCONFIGURATION}-iphoneos/facebook-ios-sdk"/*.h \
  "$FB_SDK_FRAMEWORK/Versions/A/Headers" \
  || die "Error building framework while copying SDK headers"
\cp \
  "$FB_SDK_BUILD/${BUILDCONFIGURATION}-iphoneos/facebook-ios-sdk"/*.h \
  "$FB_SDK_FRAMEWORK/Versions/A/DeprecatedHeaders" \
  || die "Error building framework while copying SDK headers to deprecated folder"
for HEADER in Legacy/FBConnect.h \
              Legacy/FBDialog.h \
              Legacy/FBFrictionlessRequestSettings.h \
              Legacy/FBLoginDialog.h \
              Legacy/Facebook.h \
              FBRequest.h \
              Legacy/FBSessionManualTokenCachingStrategy.h
do 
  \cp \
    "$FB_SDK_SRC/$HEADER" \
    "$FB_SDK_FRAMEWORK/Versions/A/DeprecatedHeaders" \
    || die "Error building framework while copying deprecated SDK headers"
done
\cp \
  "$FB_SDK_SRC/Framework/Resources"/* \
  "$FB_SDK_FRAMEWORK/Versions/A/Resources" \
  || die "Error building framework while copying Resources"
\cp -r \
  "$FB_SDK_SRC"/*.bundle \
  "$FB_SDK_FRAMEWORK/Versions/A/Resources" \
  || die "Error building framework while copying bundle to Resources"
\cp -r \
  "$FB_SDK_SRC"/*.bundle.README \
  "$FB_SDK_FRAMEWORK/Versions/A/Resources" \
  || die "Error building framework while copying README to Resources"
\cp \
  "$FB_SDK_UNIVERSAL_BINARY" \
  "$FB_SDK_FRAMEWORK/Versions/A/FacebookSDK" \
  || die "Error building framework while copying FacebookSDK"

# Current directory matters to ln.
cd "$FB_SDK_FRAMEWORK"
ln -s ./Versions/A/Headers ./Headers
ln -s ./Versions/A/Resources ./Resources
ln -s ./Versions/A/FacebookSDK ./FacebookSDK
cd "$FB_SDK_FRAMEWORK/Versions"
ln -s ./A ./Current

# -----------------------------------------------------------------------------
# Done
#

echo "Framework version info:" `perl -ne 'print "$1 " if (m/FB_IOS_SDK_VERSION_STRING @(.+)$/);' "$FB_SDK_SRC/FacebookSDK.h"` 
