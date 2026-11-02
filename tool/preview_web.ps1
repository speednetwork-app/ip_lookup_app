param(
    [string]$FlutterPath = 'flutter',
    [ValidatePattern('^preview-[a-zA-Z0-9-]+$')]
    [string]$Revision = ('preview-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')),
    [ValidateRange(1024, 65535)]
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$previewDirectory = Join-Path $projectRoot "build\web\$Revision"

# Give the HTML, compiled JS and asset URLs a new path together. A query on
# index.html alone does not change the URLs of an old cached Flutter bundle.
# This only creates build artifacts: no account storage or browser data clears.
Push-Location $projectRoot
try {
    & $FlutterPath build web --no-pub --no-wasm-dry-run `
        "--base-href=/$Revision/" "--output=$previewDirectory"
    if ($LASTEXITCODE -ne 0) {
        throw 'Versioned preview build failed.'
    }
    Write-Output "PREVIEW_URL=http://127.0.0.1:$Port/$Revision/"
} finally {
    Pop-Location
}
