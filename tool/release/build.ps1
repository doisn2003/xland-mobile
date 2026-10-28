param(
  [string]$ApiBaseUrl = 'https://xland-server-production.up.railway.app/api/v1',
  [string]$FlutterSdk = $env:XLAND_FLUTTER_SDK
)
$ErrorActionPreference = 'Stop'
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $mobileRoot
$previousGradleOptions = $env:GRADLE_OPTS
try {
  $apiUri = [Uri]$ApiBaseUrl
  if ($apiUri.Scheme -ne 'https' -or $apiUri.AbsolutePath -ne '/api/v1' -or $apiUri.UserInfo -or $apiUri.Query -or $apiUri.Fragment -or $apiUri.IsLoopback) { throw 'Release requires an HTTPS API ending in /api/v1 without credentials, query or fragment' }
  $shareHost = $apiUri.DnsSafeHost
  foreach ($privateFile in @('android/key.properties','.local/auth/google-client.json')) {
    if (-not (Test-Path -LiteralPath $privateFile)) { throw "Missing private build configuration: $privateFile" }
  }
  if (-not $FlutterSdk) {
    $pinnedSdk = Join-Path $mobileRoot '.local/flutter-3.47.5-native'
    if (Test-Path (Join-Path $pinnedSdk 'bin/flutter.bat')) { $FlutterSdk = $pinnedSdk }
  }
  $flutter = if ($FlutterSdk) { Join-Path $FlutterSdk 'bin/flutter.bat' } else { (Get-Command flutter.bat -ErrorAction Stop).Source }
  $version = (& $flutter --version --machine | ConvertFrom-Json)
  if ($LASTEXITCODE -ne 0 -or $version.frameworkVersion -ne '3.47.5') { throw 'Use the pinned Flutter 3.47.5 SDK (set XLAND_FLUTTER_SDK)' }
  $env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
  & $flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Dependencies do not match pubspec.lock' }
  & $flutter build apk --release --target-platform android-arm64,android-x64 "--dart-define=XLAND_API_BASE_URL=$ApiBaseUrl" "--dart-define=XLAND_SHARE_HOST=$shareHost" "--android-project-arg=xlandShareHost=$shareHost" --dart-define-from-file=.local/auth/google-client.json
  if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
} finally {
  $env:GRADLE_OPTS = $previousGradleOptions
  Pop-Location
}
