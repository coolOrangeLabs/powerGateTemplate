function CheckVaultBom($entity) {
    $differences = CompareErpBom -EntityBom @($entity)
    foreach ($diff in $differences) {
        if ($diff.Status -ne "Identical" -and $diff.IsHeader) {
            throw $diff.Message
        }
    }
}

function Verify-VaultRestrictionWhenErpItemNotExists {
    param($ErpMaterial, $VaultEntity)
    if (-not $erpMaterial -or $false -eq $erpMaterial) {
        $entityNumber = GetEntityNumber -Entity $VaultEntity
        throw "An item with the number '$($entityNumber)' does not exist in the ERP system."
    }
}

function Verify-VaultRestrictionWhenErpBomIsNotSynced {
    param(
        $Entity # Can be a powerVault FILE or Vault object
    )	
    $bomRows = GetVaultBomRows -Entity $Entity
    if (-not $bomRows) { continue }

    if (-not $file.Children) {
        Add-Member -InputObject $Entity -Name "Children" -Value $bomRows -MemberType NoteProperty -Force
    }
    else {
        $Entity.Children = $bomRows
    }
    try {
        CheckVaultBom $Entity | Out-Null
    }
    catch {        
        $restrictMessage = "$($_)! Please open the BOM dialog"
        throw $restrictMessage
    }
}