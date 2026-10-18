$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cargo fetch --locked
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run melos bootstrap
exit $LASTEXITCODE
