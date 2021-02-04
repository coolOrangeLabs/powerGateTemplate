function CheckVaultBom($entity) {
    $differences = CompareErpBom -EntityBom @($entity)
    foreach ($diff in $differences) {
        if ($diff.Status -ne "Identical" -and $diff.IsHeader) {
            throw $diff.Message
        }
    }
}

function Add-VaultRestrictionWhenErpItemNotExists {
    param($ErpMaterial)
    if (-not $erpMaterial -or $false -eq $erpMaterial) {
        $restrictMessage = "An item with the number '$($file._PartNumber)' does not exist in the ERP system."
        Add-VaultRestriction -EntityName $file._Name -Message $restrictMessage
        return $true
    }
}

function Add-VaultRestrictionWhenErpBomIsNotSynced {
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
        Add-VaultRestriction -EntityName $Entity._Name -Message $restrictMessage
        return $true
    }
}