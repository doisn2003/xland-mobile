param([string]$ApiBaseUrl = 'https://xland-server-production.up.railway.app/api/v1')
$ErrorActionPreference = 'Stop'
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $mobileRoot
$previousGradleOptions = $env:GRADLE_OPTS
try {
  if (-not $ApiBaseUrl.StartsWith('https://') -or -not $ApiBaseUrl.EndsWith('/api/v1')) { throw 'Release requires an HTTPS API ending in /api/v1' }
  foreach ($privateFile in @('android/key.properties','.local/auth/google-client.json')) {
    if (-not (Test-Path -LiteralPath $privateFile)) { throw "Missing private build configuration: $privateFile" }
  }
  $env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
  & './.local/flutter-3.47.5-native/bin/flutter.bat' build apk --release --target-platform android-arm64,android-x64 "--dart-define=XLAND_API_BASE_URL=$ApiBaseUrl" --dart-define-from-file=.local/auth/google-client.json
  if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
} finally {
  $env:GRADLE_OPTS = $previousGradleOptions
  Pop-Location
}
