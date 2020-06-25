
Get-ChildItem -LiteralPath 'C:\ProgramData\coolOrange\powerGate\Modules\' -File -Recurse -Force -Filter '*.ps*' | `
ForEach-Object {
    Write-Host "Import shared module $($_.FullName)"
    Import-Module $_.FullName -Global -Force -DisableNameChecking
}
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerJobs.txt"
$global:loggingSettings.WriteHost = $true
Write-Host "Initialized logging to file: $($global:loggingSettings.LogFile)"