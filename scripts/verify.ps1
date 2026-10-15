$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
function Find-ProjectTool($Name) {
    $localPath = Join-Path (Get-Location) ".tools/$Name.exe"
    if (Test-Path -LiteralPath $localPath) { return $localPath }
    return (Get-Command $Name -ErrorAction Stop).Source
}
$luneTool = Find-ProjectTool 'lune'
$styluaTool = Find-ProjectTool 'stylua'
$rojoTool = Find-ProjectTool 'rojo'
python scripts/bundle.py --check
if ($LASTEXITCODE -ne 0) { throw 'Distribution is stale; run python scripts/bundle.py' }
python -m unittest discover -s tests -p '*_test.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Bundle build tests failed' }
& $luneTool run scripts/check.luau
if ($LASTEXITCODE -ne 0) { throw 'Luau compilation failed' }
& $luneTool run tests/run.luau
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
& $styluaTool --check src demo tests scripts main.client.lua
if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed' }
New-Item -ItemType Directory -Force build | Out-Null
& $rojoTool build default.project.json --output build/MohammadAndAli-Demo.rbxlx
if ($LASTEXITCODE -ne 0) { throw 'Demo build failed' }
& $rojoTool build production.project.json --output build/MohammadAndAli-Integration.rbxlx
if ($LASTEXITCODE -ne 0) { throw 'Integration build failed' }
& $rojoTool build standalone.project.json --output build/MohammadAndAli-Standalone.rbxlx
if ($LASTEXITCODE -ne 0) { throw 'Standalone build failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Git whitespace check failed' }
