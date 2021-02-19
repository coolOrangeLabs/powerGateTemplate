
Get-ChildItem -LiteralPath 'C:\ProgramData\coolOrange\powerGate\Modules\' -File -Recurse -Force -Filter '*.ps*' | `
    ForEach-Object {
    Write-Host "Import shared module $($_.FullName)"
    Import-Module $_.FullName -Global -Force -DisableNameChecking
}

$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerJobs.log"
Set-LogFilePath -Path $logPath
