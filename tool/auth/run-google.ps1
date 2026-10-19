param(
  [string]$DeviceId = '',
  [string]$ApiBaseUrl = 'http://10.0.2.2:3004/api/v1',
  [string]$MediaBaseUrl = '',
  [string]$ConfigPath = '',
  [switch]$Run
)
$ErrorActionPreference = 'Stop'
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
function Resolve-AuthEndpoint([string]$Value, [string]$Label, [bool]$RequireApiPath) {
  $endpoint = $null
  if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$endpoint) -or
      $endpoint.Scheme -notin @('http', 'https') -or $endpoint.UserInfo -or
      $endpoint.Query -or $endpoint.Fragment) {
    throw "$Label must be an absolute HTTP(S) URL without credentials, query or fragment."
  }
  if ($endpoint.Scheme -eq 'http' -and $endpoint.Host -notin @('localhost', '127.0.0.1', '10.0.2.2', '::1', '[::1]')) {
    throw "$Label requires HTTPS outside the local emulator/loopback hosts."
  }
  if ($RequireApiPath -and $endpoint.AbsolutePath.TrimEnd('/') -ne '/api/v1') {
    throw "$Label must end with /api/v1."
  }
  return $endpoint.AbsoluteUri.TrimEnd('/')
}
$ApiBaseUrl = Resolve-AuthEndpoint $ApiBaseUrl 'ApiBaseUrl' $true
$authHasMediaOverride = -not [string]::IsNullOrWhiteSpace($MediaBaseUrl)
if ($authHasMediaOverride) {
  $MediaBaseUrl = Resolve-AuthEndpoint $MediaBaseUrl 'MediaBaseUrl' $false
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $mobileRoot '.local\auth\google-client.json'
} elseif (-not [IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath = Join-Path $mobileRoot $ConfigPath
}
$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw 'Create .local/auth/google-client.json from tool/auth/google-client.example.json first.' }
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$allowed = @('GOOGLE_SERVER_CLIENT_ID', 'GOOGLE_CLIENT_ID')
foreach ($field in $config.PSObject.Properties.Name) {
  if ($field -notin $allowed) { throw 'Google client config contains an unsupported field. Never put secrets in Dart defines.' }
}
if ([string]::IsNullOrWhiteSpace($config.GOOGLE_SERVER_CLIENT_ID) -or
    $config.GOOGLE_SERVER_CLIENT_ID -notmatch '^[\w.-]+\.apps\.googleusercontent\.com$') {
  throw 'GOOGLE_SERVER_CLIENT_ID must be the OAuth Web client ID.'
}
if ($config.GOOGLE_CLIENT_ID -and $config.GOOGLE_CLIENT_ID -notmatch '^[\w.-]+\.apps\.googleusercontent\.com$') {
  throw 'GOOGLE_CLIENT_ID must be empty on Android or the platform OAuth client ID.'
}
$flutterPath = Join-Path $mobileRoot '.local\flutter-3.47.5-native\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Pinned Flutter SDK is missing.' }
Write-Output "API base URL: $ApiBaseUrl"
$authFlutterArguments = @('run', '-d', $DeviceId, '-t', 'lib/main.dart', "--dart-define-from-file=$ConfigPath", "--dart-define=XLAND_API_BASE_URL=$ApiBaseUrl")
if ($authHasMediaOverride) {
  Write-Output "Media override URL: $MediaBaseUrl"
  $authFlutterArguments += "--dart-define=XLAND_DEMO_MEDIA_BASE_URL=$MediaBaseUrl"
} else {
  Write-Output 'Media source: API/Storage (no local override).'
}
$authFlutterArguments | Where-Object { $_ -like '--dart-define=*' } | ForEach-Object { Write-Output "Dart define: $_" }
if (-not $Run) {
  Write-Output 'Public Google client IDs validated. No build/emulator started.'
  Write-Output 'During the agreed Android window, invoke this script with -Run -DeviceId <your-device-id>; override -ApiBaseUrl/-MediaBaseUrl explicitly for another target.'
  exit 0
}
if ([string]::IsNullOrWhiteSpace($DeviceId)) { throw 'Choose an explicit device ID for the agreed build window.' }
Push-Location -LiteralPath $mobileRoot
try {
  & $flutterPath @authFlutterArguments
  $authRunExit = $LASTEXITCODE
} finally { Pop-Location }
exit $authRunExit
