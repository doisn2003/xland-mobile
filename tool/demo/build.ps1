param([switch]$RefreshSnapshot)
$ErrorActionPreference='Stop'
$demoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $demoRoot
$previousGradleOptions=$env:GRADLE_OPTS
try {
  if($RefreshSnapshot -or -not(Test-Path -LiteralPath 'assets/prepared-demo/snapshot.json')){
    & node tool/demo/prepare.mjs
    if($LASTEXITCODE -ne 0){throw 'Snapshot preparation is incomplete; inspect assets/prepared-demo/report.json.'}
  }
  foreach($privateFile in @('android/key.properties','.local/auth/google-client.json')){
    if(-not(Test-Path -LiteralPath $privateFile)){throw "Missing private local file: $privateFile"}
  }
  $env:GRADLE_OPTS='-Dorg.gradle.daemon=false'
  & ./.local/flutter-3.47.5-native/bin/flutter.bat build apk --release --target lib/main_demo.dart --target-platform android-arm64,android-x64 --dart-define=XLAND_PREPARED_DEMO=true --dart-define=XLAND_API_BASE_URL=https://p01--xland--y56gnzgzjsqm.code.run/api/v1 --dart-define-from-file=.local/auth/google-client.json
  if($LASTEXITCODE -ne 0){throw 'Prepared demo APK build failed.'}
}finally{
  $env:GRADLE_OPTS=$previousGradleOptions
  Pop-Location
}
