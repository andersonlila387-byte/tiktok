#!/usr/bin/env bash
# Builds the Flutter web app and copies it to public/, which Vercel serves.
# Run this, commit public/, and push whenever the app changes.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/pulse_analytics"
flutter build web --release
rm -rf "$root/public"
cp -r build/web "$root/public"
echo "Copied build to public/"
