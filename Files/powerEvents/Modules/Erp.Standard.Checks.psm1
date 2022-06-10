function Test-ErpItemExists {
    param($ErpMaterial, $VaultEntity)
    if (-not $erpMaterial -or $false -eq $erpMaterial) {
        $entityNumber = GetEntityNumber -Entity $VaultEntity
        throw "An item with the number '$($entityNumber)' does not exist in the ERP system."
    }
    Log -End
}

function Test-ErpBomIsSynced {
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

    $differences = CompareErpBom -VaultBom @($Entity)
    $anyHeaderIsDifferent = $differences | where { $_.Status -ne "Identical" -and $_.IsHeader }
    if ($anyHeaderIsDifferent) {
        throw "Open the BOM dialog, because the ERP BOM is different then in Vault!"
    }
    Log -End
}