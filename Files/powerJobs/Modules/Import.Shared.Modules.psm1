
Get-ChildItem -LiteralPath 'C:\ProgramData\coolOrange\Modules\' -File -Recurse -Force -Filter '*.ps*' | `
ForEach-Object {
    Import-Module $_.FullName -Global -Force -DisableNameChecking
}
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerJobs.txt"
$global:loggingSettings.WriteHost = $true