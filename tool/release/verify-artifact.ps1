param(
  [string]$ApkPath = 'build/app/outputs/flutter-apk/app-release.apk',
  [string]$EvidencePath = '.local/railway-apk-content.json',
  [string]$ApiBaseUrl = 'https://xland-server-production.up.railway.app/api/v1'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ApkPath))
try {
  $entries = @($archive.Entries | ForEach-Object { $_.FullName })
  $unexpected = @($entries | Where-Object { $_ -match '(^|/)(\.env|\.local|key\.properties)|\.(jks|keystore)$' })
  if ($unexpected.Count -gt 0) { throw 'Private file found in APK' }
  $native = @($entries | Where-Object { $_ -match '^lib/' })
  $abis = @($native | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
  if (($abis -join ',') -ne 'arm64-v8a,x86_64') { throw 'APK ABI mismatch' }
  foreach ($abi in $abis) {
    if (-not $entries.Contains("lib/$abi/libapp.so") -or -not $entries.Contains("lib/$abi/libflutter.so")) {
      throw 'Flutter AOT or engine missing for advertised ABI'
    }
    $stream = $archive.GetEntry("lib/$abi/libapp.so").Open()
    $memory = [System.IO.MemoryStream]::new()
    try { $stream.CopyTo($memory); $binaryText = [System.Text.Encoding]::ASCII.GetString($memory.ToArray()) }
    finally { $stream.Dispose(); $memory.Dispose() }
    if (-not $binaryText.Contains($ApiBaseUrl)) { throw 'Expected API origin absent from AOT' }
  }
  [ordered]@{ checkedAt=(Get-Date).ToUniversalTime().ToString('o'); abis=$abis; nativeLibraries=$native; privateFileEntries=0; configuredApiFoundInBothAbis=$true; sha256=(Get-FileHash $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant() } |
    ConvertTo-Json | Tee-Object -FilePath $EvidencePath
} finally { $archive.Dispose() }
