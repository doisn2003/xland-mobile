#!/usr/bin/env bash
# Run on macOS; never uploads the resulting archive or changes Apple accounts.
set -euo pipefail
cd "$(dirname "$0")/../.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'IPA builds require macOS and Xcode.' >&2
  exit 1
fi
: "${XLAND_APPLE_TEAM_ID:?Set XLAND_APPLE_TEAM_ID to your Apple Developer Team ID}"
flutter_bin="${XLAND_FLUTTER_SDK:+$XLAND_FLUTTER_SDK/bin/}flutter"
auth_file="${XLAND_IOS_AUTH_FILE:-.local/auth/google-client-ios.json}"
export_method="${XLAND_IOS_EXPORT_METHOD:-app-store}"
case "$export_method" in app-store|ad-hoc|development|enterprise) ;; *) echo 'Unsupported IPA export method' >&2; exit 1;; esac
xcodebuild -version
"$flutter_bin" --version --machine | python3 -c 'import json,sys; assert json.load(sys.stdin)["frameworkVersion"] == "3.47.5", "Use Flutter 3.47.5"'
"$flutter_bin" config --enable-swift-package-manager
python3 - "$auth_file" <<'PY'
import json, os, pathlib, re, sys
auth = json.loads(pathlib.Path(sys.argv[1]).read_text())
pattern = r'[0-9]+-[a-zA-Z0-9-]+\.apps\.googleusercontent\.com'
for key in ('GOOGLE_CLIENT_ID', 'GOOGLE_SERVER_CLIENT_ID'):
    if not re.fullmatch(pattern, auth.get(key, '')):
        raise SystemExit(f'Missing or invalid {key}; use an iOS client plus the existing web/server client')
if set(auth) != {'GOOGLE_CLIENT_ID', 'GOOGLE_SERVER_CLIENT_ID'}:
    raise SystemExit('The iOS auth file must contain only the two public OAuth client IDs')
team = os.environ['XLAND_APPLE_TEAM_ID']
if not re.fullmatch(r'[A-Z0-9]{10}', team):
    raise SystemExit('Invalid Apple Team ID')
reversed_id = '.'.join(reversed(auth['GOOGLE_CLIENT_ID'].split('.')))
pathlib.Path('ios/Flutter/GoogleSignIn.xcconfig').write_text(
    '// Generated locally; do not commit.\n'
    f'GOOGLE_REVERSED_CLIENT_ID = {reversed_id}\nDEVELOPMENT_TEAM = {team}\n')
PY
"$flutter_bin" pub get --enforce-lockfile
"$flutter_bin" build ipa --release --export-method "$export_method" \
  --dart-define-from-file=tool/release/production.json \
  --dart-define-from-file="$auth_file"
find build/ios/ipa -maxdepth 1 -name '*.ipa' -print
