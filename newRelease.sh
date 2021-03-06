#!/bin/bash

set -euo pipefail
# set -x

function help # MSG
{
    cat << EOT
usage: newRelease [--macos][--ios] major | minor | patch | build

Update version attributes for the project then build, test, archive, and upload
new payloads to App Store. THis is done for both iOS and macOS builds by default
but can be limited to just one via --macos or --ios.

Note that the build version is always updated to be the current date/time in
YYYYMMDDhhmm format.

major - increment the major version number (and set minor and patch to 0)
minor - increment the minor version number (and set patch to 0)
patch - increment the patch version number
build - only increment the build number, leaving major, minor, and patch as-is.
EOT
}

function log #
{
    echo "-- ${@}"
}

function error #
{
    echo "** ${@}"
    help
    exit 1
}

CMD=""
PLATFORMS="macos ios"

while [[ "$#" -gt 0 ]]; do
    case "${1}" in
        "--macos") PLATFORMS="macos" ;;
        "--ios") PLATFORMS="ios" ;;
        "major") CMD="major"; python3 bumpVersions.py -d "${PWD}" -1 ;;
        "minor") CMD="minor"; python3 bumpVersions.py -d "${PWD}" -2 ;;
        "patch") CMD="patch"; python3 bumpVersions.py -d "${PWD}" -3 ;;
        "build") CMD="build"; python3 bumpVersions.py -d "${PWD}" -b ;;
        *) error "invalid arg - ${1}" ;;
    esac
    shift 1
done

[[ -z "${CMD}" ]] && error "missing one of 'major', 'minor', 'patch', or 'build'"

set -- *.xcodeproj
PROJECT="${1}"
log "using PROJECT='${PROJECT}'"

set -- $(tail -1 "${HOME}/zzz.log")
VERSION="${2#v}"
[[ -z "${VERSION}" ]] && error "failed to get VERSION"
log "using VERSION='${VERSION}'"

if [[ ! -f "${PWD}/exportOptions.plist" ]]; then
    set -- $(grep 'DEVELOPMENT_TEAM' "${PWD}/Configuration/Common.xcconfig")
    DEVELOPMENT_TEAM="${3}"
    log "using DEVELOPMENT_TEAM='${DEVELOPMENT_TEAM}'"
    log "creating ${PWD}/exportOptions.plist"

    cat << EOT > "${PWD}/exportOptions.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadBitcode</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOT
fi

function buildTestDeploy # SCHEME DESTINATION
{
    local SCHEME="${1}"
    local DESTINATION="${2}"
    local DATE=$(date +'%Y-%m-%d')
    local HHMM=$(date '%H.%M')
    local ARCHIVE_DIR="${HOME}/Library/Developer/Xcode/Archives/${DATE}"
    local ARCHIVE="${ARCHIVE_DIR}/${SCHEME} ${DATE},${HHMM}.xcarchive"

    mkdir -p "${ARCHIVE_DIR}"

    # Compile and test
    log "running tests"
    xcodebuild \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        test

    log "building release"
    xcodebuild \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -configuration Release build

    [[ -f "${ARCHIVE}" ]] && rm -f "${ARCHIVE}"

    log "generating archive"
    xcodebuild \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -configuration AppStoreDistribution \
        archive \
        -archivePath "${ARCHIVE}"

    xcodebuild \
        -exportArchive \
        -archivePath "${ARCHIVE}" \
        -exportOptionsPlist exportOptions.plist \
        -exportPath "${PWD}"
}

for EACH in ${PLATFORMS}; do
    case "${EACH}" in
        "ios") buildTestDeploy 'iOS App' 'platform=iOS Simulator,name=iPhone SE (2nd generation)' ;;
        "macos") buildTestDeploy 'macOS App' 'platform=macOS' ;;
    esac
done

log "committing version changes"
echo git add -u
echo git commit -m "v${VERSION}"
if [[ "${CMD}" != "build" ]]; then
    log "tagging repo with ${VERSION}"
    echo git tag "${VERSION}"
fi

log "pushing changes to remote"
git push

if [[ "${CMD}" != "build" ]]; then
    log "pushing updated tags to remote"
    echo git push --tags
fi
