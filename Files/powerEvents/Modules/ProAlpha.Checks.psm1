
function Verify-VaultRestrictionWhenProAlphaStatusIsNotOk {
    param($ErpMaterial)

    Log -Begin
    $notAllowedErpStates = @("gesperrt", "ausgelaufen")
    if ($ErpMaterial.Status -in $notAllowedErpStates) {
        throw  "In ProAlpha the status of the item is $($ErpMaterial.Status) and therefore it is not allowed to change the state in Vault!"
    }
    Log -End
}