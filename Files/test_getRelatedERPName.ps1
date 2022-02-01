Import-Module "C:\Users\JulianTollGoss\GitHub\powerGateTemplate\Files\powerGate\Modules\Initialize.psm1"
Import-Module "C:\Users\JulianTollGoss\GitHub\powerGateTemplate\Files\powerGate\Modules\Communication.psm1"
Import-Module powerVault
$Error.Clear()
$conn = Open-VaultConnection -Server "localhost" -Vault "Vault1" -User "Administrator" -Password ""
if (-not $conn){
    Write-Host $Error[0]
}

$currentVault = $VaultConnection.Vault
$relatedPGS = getRelatedPGServerName
ShowMessageBox -Message "You are in Vault $currentVault`nRelated Powergate Server: $relatedPGS"
