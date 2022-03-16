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
            #Update-BomWindowEntity $entity -Status "Error" -Tooltip "Part Number is empty!"
            if ($entity._VaultStatus.Status.LockState -eq "Locked") {
                Update-BomWindowEntity $entity -Status "Error" -Tooltip "Entity is locked"
            }
            else {
                Update-BomWindowEntity $entity -Status "New" -Tooltip "Item does not exist in ERP. Will be created."
            }
            continue
        }
        $erpMaterial = GetErpMaterialWithPGError -number $number
        if (-not $erpMaterial.Entity) {         
            #TODO: check if obligatory fields are filled!
            if ($number.Length -gt 20) {
                $tooltip = "The number '$($number)' is longer than 20 characters. The ERP item cannot be created"
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $tooltip
            }
            else {
                Update-BomWindowEntity $entity -Status "New" -Tooltip "Item does not exist in ERP. Will be created."
            }
        }
        else {
            if (-not $entity._EntityTypeID) {
                Update-BomWindowEntity $entity -Status "Identical" -Tooltip "Virtual Component or Raw Material where no file in Vault is present"
            }
            else {
                $differences = CompareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
                if ($differences) {
                    Update-BomWindowEntity $entity -Status "Different" -Tooltip $differences
                }
                else {
                    Update-BomWindowEntity $entity -Status "Identical" -Tooltip "Item is identical between Vault and ERP"
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
            $erpMaterial = CreateErpMaterialWithPGError -erpMaterial $erpMaterial
            if ($erpMaterial.ErrorMessage) {  
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $erpMaterial.ErrorMessage
            }
            else {
                Update-BomWindowEntity $entity -Status "Identical" -Properties $entity
                SetEntityProperties -erpMaterial $erpMaterial.Entity -vaultEntity $entity
            }
        }
        elseif ($entity._Status -eq "Different") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
            $erpMaterial = UpdateErpMaterialWithPGError -erpMaterial $erpMaterial
            if ($erpMaterial.ErrorMessage) {
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $erpMaterial.ErrorMessage
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

function Check-Boms($entityBoms) {
    [array]::Reverse($entityBoms)
    foreach ($entityBom in $entityBoms) {

        if ($entityBom._Status -ne "Unknown") {
            Update-BomWindowEntity -InputObject $entityBom -Status $entityBom._Status -Tooltip $entityBom.Message  
			foreach ($entityBomRow in $entityBom.Children) {
                Update-BomWindowEntity -InputObject $entityBomRow -Status $entityBomRow._Status -Tooltip $entityBomRow.Message  
            }
            continue
        }
        
        $differences = CompareErpBom -entityBom $entityBom
        foreach ($diff in $differences) {
            if ($diff.Status -eq "Remove" -and $diff.Parent) {
                $remove = Add-BomWindowEntity -Parent $diff.Parent -Type BomRow -Properties $diff.AffectedObject
                Update-BomWindowEntity $remove -Status $diff.Status -Tooltip $diff.Message
            }
            else {
                Update-BomWindowEntity -InputObject $diff.AffectedObject -Status $diff.Status -Tooltip $diff.Message            
            }
        }
    }
}

function Transfer-Boms($entityBoms) {
    [array]::Reverse($entityBoms)
    foreach ($entityBom in $entityBoms) {
        $parentNumber = GetEntityNumber -entity $entityBom
        if ($entityBom._Status -eq "New") {
            $erpBomRows = @()
            foreach ($entityBomRow in $entityBom.Children) {
                $erpBomRow = NewErpBomRow          
                $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $entityBomRow
                $erpBomRows += $erpBomRow
            }
            $erpBomHeader = NewErpBomHeader   
            $erpBomHeader = PrepareErpBomHeader -erpBomHeader $erpBomHeader -vaultEntity $entityBom
            $erpBomHeader.BomRows = $erpBomRows
            $erpBomHeader = CreateErpBomHeaderWithPGError -erpBomHeader $erpBomHeader
            if ($erpBomHeader.ErrorMessage) {
                Update-BomWindowEntity $entityBom -Status "Error" -Tooltip $erpBomHeader.ErrorMessage
                foreach ($entityBomRow in $entityBom.Children) {
                    Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomHeader.ErrorMessage
                }
            }
            else {
                Update-BomWindowEntity $entityBom -Status "Identical"
                foreach ($entityBomRow in $entityBom.Children) {
                    Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                }
            }
        }
        elseif ($entityBom._Status -eq "Different") {
            $bomHeaderStatus = "Identical"
            $bomChildrenRemoveFirst = $entityBom.Children | Sort-Object -Property _Status -Descending
            foreach ($entityBomRow in $bomChildrenRemoveFirst) {
                $childNumber = GetEntityNumber -entity $entityBomRow
                if ($entityBomRow._Status -eq "New") {
                    $erpBomRow = NewErpBomRow          
                    $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $entityBomRow
                    $erpBomRow = CreateErpBomRowPGError -erpBomRow $erpBomRow
                    if ($erpBomRow.ErrorMessage) {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow.ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                    }
                }
                elseif ($entityBomRow._Status -eq "Different") {
                    $erpBomRow = GetErpBomRowWithPGError -parentNumber $parentNumber -childNumber $childNumber -position $entityBomRow.Bom_PositionNumber             
                    $erpBomRow.Entity.Quantity = $entityBomRow.Bom_Quantity
                    $erpBomRow = UpdateErpBomRowPGError -erpBomRow $erpBomRow.Entity
                    if ($erpBomRow.ErrorMessage) {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow.ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                    }
                }
                elseif ($entityBomRow._Status -eq "Remove") {
                    $erpBomRow = RemoveErpBomRowPGError -parentNumber $parentNumber -childNumber $entityBomRow.Bom_Number -position $entityBomRow.Bom_PositionNumber
                    if ($erpBomRow.ErrorMessage) {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow._ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                    else {
                        $entityBomRow | Remove-BomWindowEntity
                    }
                }
                else {
                    Update-BomWindowEntity $entityBomRow -Status $entityBomRow._Status
                }
            }
            Update-BomWindowEntity $entityBom -Status $bomHeaderStatus
        }
        else {
            # removes the dialog questionmarks for rows that haven't been touched. should be fixed in the core product!
            Update-BomWindowEntity $entityBom -Status $entityBom._Status
            foreach ($entityBomRow in $entityBom.Children) {
                Update-BomWindowEntity $entityBomRow -Status $entityBomRow._Status
            }
        }
    }
}
#endregion