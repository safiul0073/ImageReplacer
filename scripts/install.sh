#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Image Replacer"
ZIP_NAME="Image-Replacer-macOS.zip"
INSTALL_DIR="/Applications"

usage() {
  cat <<USAGE
Install Image Replacer without Xcode.

Usage:
  REPO=owner/repository ./scripts/install.sh
  ./scripts/install.sh owner/repository

Example:
  ./scripts/install.sh safiul/Image-Replacer

This script downloads the latest GitHub Release asset named:
  ${ZIP_NAME}

Then it installs:
  ${APP_NAME}.app

into:
  ${INSTALL_DIR}
USAGE
}

REPO="${1:-${REPO:-}}"

if [[ "${REPO}" == "-h" || "${REPO}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${REPO}" ]]; then
  echo "Error: missing GitHub repository." >&2
  echo >&2
  usage >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

if ! command -v ditto >/dev/null 2>&1; then
  echo "Error: ditto is required." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

ZIP_PATH="${WORK_DIR}/${ZIP_NAME}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ZIP_NAME}"

echo "Downloading ${APP_NAME} from:"
echo "${DOWNLOAD_URL}"

curl --fail --location --output "${ZIP_PATH}" "${DOWNLOAD_URL}"

echo "Unzipping..."
ditto -x -k "${ZIP_PATH}" "${WORK_DIR}"

APP_PATH="${WORK_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: ${APP_NAME}.app was not found inside ${ZIP_NAME}." >&2
  exit 1
fi

DESTINATION="${INSTALL_DIR}/${APP_NAME}.app"

if [[ -d "${DESTINATION}" ]]; then
  echo "Replacing existing ${DESTINATION}"
  rm -rf "${DESTINATION}"
fi

echo "Installing to ${DESTINATION}"
cp -R "${APP_PATH}" "${DESTINATION}"

echo "Removing quarantine flag if present..."
xattr -dr com.apple.quarantine "${DESTINATION}" 2>/dev/null || true

echo
echo "Installed ${APP_NAME}."
echo "Open it from Applications, or run:"
echo "  open '${DESTINATION}'"

