function ShowBomWindow {
    $entity = GetSelectedObject
    Show-BomWindow -Entity $entity
    RefreshView
}

#region BOm Window functions: 
#https://www.coolorange.com/wiki/doku.php?id=powergate:code_reference:commandlets:show-bomwindow:required_functions
#
#known limitations:
#https://support.coolorange.com/support/solutions/articles/22000243916-same-bomrows-do-not-update-status
function Get-BomRows($entity) {
    $bomRows = GetVaultBomRows -Entity $entity
    return $bomRows
}

function Check-Items($entities) {
    foreach ($entity in $entities) {
        $number = GetEntityNumber -entity $entity
        if ($null -eq $number -or $number -eq "") {
            if ($entity._VaultStatus.Status.LockState -eq "Locked") {
                Update-BomWindowEntity $entity -Status "Error" -StatusDetails "Entity is locked"
            }
            else {
                Update-BomWindowEntity $entity -Status "New" -StatusDetails "Item does not exist in ERP. Will be created."
            }
            continue
        }

        $getErpMaterialResult = GetErpMaterial -number $number
		if ($getErpMaterialResult.ErrorMessage) {
			Update-BomWindowEntity $entity -Status "Error" -StatusDetails "Couldn't read material from server! ErrorMessage: '$($getErpMaterialResult.ErrorMessage)'"
			continue
		}

		if (-not $getErpMaterialResult.Entity) {
            #TODO: check if obligatory fields are filled!
			if ($number.Length -gt 20) {
                $statusDetails = "The number '$($number)' is longer than 20 characters. The ERP item cannot be created"
                Update-BomWindowEntity $entity -Status "Error" -StatusDetails $statusDetails
            }
            Update-BomWindowEntity $entity -Status "New" -StatusDetails "Item does not exist in ERP. Will be created."
        }
        else {
            if (-not $entity._EntityTypeID) {
                Update-BomWindowEntity $entity -Status "Identical" -StatusDetails "Virtual Component or Raw Material where no file in Vault is present"
            }
            else {
                $differences = CompareErpMaterial -erpMaterial $getErpMaterialResult.Entity -vaultEntity $entity
                if ($differences) {
                    Update-BomWindowEntity $entity -Status "Different" -StatusDetails $differences
                }
                else {
                    Update-BomWindowEntity $entity -Status "Identical" -StatusDetails "Item is identical between Vault and ERP"
                }
            }
        }
    }
}

function Transfer-Items($entities) {
    foreach ($entity in $entities) {
        if ($entity._Status -eq "New") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
			$createErpMaterialResult = CreateErpMaterial -erpMaterial $erpMaterial
			if($createErpMaterialResult.ErrorMessage) {
                Update-BomWindowEntity $entity -Status "Error" -StatusDetails $createErpMaterialResult.ErrorMessage
            }
            else {
                Update-BomWindowEntity $entity -Status "Identical" -Properties $entity
                SetEntityProperties -erpMaterial $createErpMaterialResult.Entity -vaultEntity $entity
            }
        }
        elseif ($entity._Status -eq "Different") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
			$updateErpMaterialResult = UpdateErpMaterial -erpMaterial $erpMaterial
			if($updateErpMaterialResult.ErrorMessage) {
                Update-BomWindowEntity $entity -Status "Error" -StatusDetails $updateErpMaterialResult.ErrorMessage
            }
            else {
                Update-BomWindowEntity $entity -Status "Identical"
            }
        }
        else {
            Update-BomWindowEntity $entity -Status $entity._Status
        }
    }
}

function Check-Boms($VaultBoms) {
    [array]::Reverse($VaultBoms)
    foreach ($vaultBom in $VaultBoms) {

        foreach ($vaultBomRow in $vaultBom.Children) {
            if ($vaultBomRow._Status -eq "Remove") {
                Remove-BomWindowEntity -InputObject $vaultBomRow
            }
        }  

        if ($vaultBom._Status -ne "Unknown") {
            Update-BomWindowEntity -InputObject $vaultBom -Status $vaultBom._Status -StatusDetails $vaultBom.Message
			foreach ($vaultBomRow in $vaultBom.Children) {
                Update-BomWindowEntity -InputObject $vaultBomRow -Status $vaultBomRow._Status -StatusDetails $vaultBomRow.Message
            }
            continue
        }
        
        $differences = CompareErpBom -VaultBom $vaultBom
        foreach ($diff in $differences) {
            if ($diff.Status -eq "Remove" -and $diff.Parent) {
                $remove = Add-BomWindowEntity -Parent $diff.Parent -Type BomRow -Properties $diff.AffectedObject
                Update-BomWindowEntity $remove -Status $diff.Status -StatusDetails $diff.Message
            }
            else {
                Update-BomWindowEntity -InputObject $diff.AffectedObject -Status $diff.Status -StatusDetails $diff.Message
            }
        }
    }
}

function Transfer-Boms($VaultBoms) {
    [array]::Reverse($VaultBoms)
    foreach ($vaultBom in $VaultBoms) {
        $parentNumber = GetEntityNumber -entity $vaultBom

        if ($vaultBom._Status -eq "New") {
            $erpBomRows = @()
            foreach ($vaultBomRow in $vaultBom.Children) {
                $erpBomRow = NewErpBomRow
                $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $vaultBomRow
                $erpBomRows += $erpBomRow
            }
            $erpBomHeader = NewErpBomHeader
            $erpBomHeader = PrepareErpBomHeader -erpBomHeader $erpBomHeader -vaultEntity $vaultBom
            $erpBomHeader.BomRows = $erpBomRows

			$createErpBomHeaderResult = CreateErpBomHeader -erpBomHeader $erpBomHeader
			if($createErpBomHeaderResult.ErrorMessage) {
				Update-BomWindowEntity $vaultBom -Status "Error" -StatusDetails $createErpBomHeaderResult.ErrorMessage
				foreach ($vaultBomRow in $vaultBom.Children) {
					Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $createErpBomHeaderResult.ErrorMessage
				}
			}
			else {
				Update-BomWindowEntity $vaultBom -Status "Identical"
				foreach ($vaultBomRow in $vaultBom.Children) {
					Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""
				}
			}

			continue
        }

        if ($vaultBom._Status -eq "Different") {
            $bomHeaderStatus = "Identical"
			# Status: "Unknown", "Remove", "Identical", "Error"
            $vaultBomRows = $vaultBom.Children | Sort-Object -Property _Status -Descending
            foreach ($vaultBomRow in $vaultBomRows) {

                if ($vaultBomRow._Status -eq "Remove") {
                    $removeErpBomRowResult = RemoveErpBomRow -parentNumber $parentNumber -childNumber $vaultBomRow.Bom_Number -position $vaultBomRow.Bom_PositionNumber
					if ($removeErpBomRowResult.ErrorMessage) {
						Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $removeErpBomRowResult.ErrorMessage
						$bomHeaderStatus = "Error"
					}
					else {
						$vaultBomRow | Remove-BomWindowEntity
					}

					continue
                }

				$childNumber = GetEntityNumber -entity $vaultBomRow
				if ($vaultBomRow._Status -eq "Different") {
                    $getErpBomRowResult = GetErpBomRow -parentNumber $parentNumber -childNumber $childNumber -position $vaultBomRow.Bom_PositionNumber
					if($getErpBomRowResult.ErrorMessage) {
						Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $getErpBomRowResult.ErrorMessage
						$bomHeaderStatus = "Error"
						continue
					}
					
                    $updateErpBomRowResult = UpdateErpBomRow -ErpBomRow $getErpBomRowResult.Entity -VaultEntity $vaultBomRow
					if($updateErpBomRowResult.ErrorMessage) {
						Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $updateErpBomRowResult.ErrorMessage
						$bomHeaderStatus = "Error"
						continue
					}

					Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""

					continue
                }

                if ($vaultBomRow._Status -eq "New") {
                    $erpBomRow = NewErpBomRow
                    $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $vaultBomRow

					$createErpBomRowResult = CreateErpBomRow -erpBomRow $erpBomRow
					if($createErpBomRowResult.ErrorMessage) {
						Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $createErpBomRowResult.ErrorMessage
						$bomHeaderStatus = "Error"
					}
					else {
						Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""
					}
                }
                else {
                    Update-BomWindowEntity $vaultBomRow -Status $vaultBomRow._Status
                }
            }

            Update-BomWindowEntity $vaultBom -Status $bomHeaderStatus
        }
        else {
            # removes the dialog questionmarks for rows that haven't been touched. should be fixed in the core product!
            Update-BomWindowEntity $vaultBom -Status $vaultBom._Status
            foreach ($vaultBomRow in $vaultBom.Children) {
                Update-BomWindowEntity $vaultBomRow -Status $vaultBomRow._Status
            }
        }
    }
}
#endregion