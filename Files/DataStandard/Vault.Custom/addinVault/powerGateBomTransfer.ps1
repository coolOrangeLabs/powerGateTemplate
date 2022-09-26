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
        

        if (-not $number) {
            if ($entity._VaultStatus.Status.LockState -eq "Locked") {
                Update-BomWindowEntity $entity -Status "Error" -StatusDetails "Number is empty! Entity is locked"
            }else {
                Update-BomWindowEntity $entity -Status "New" -StatusDetails "Item does not exist in ERP. Will be created."
            }
            continue
        }
    
        $erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number.ToUpper() }
        if ($? -eq $false) {
            continue
        }
 

        if (-not $erpMaterial) {
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
                $differences = CompareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
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
            $erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $entity
            $createErpMaterial = Add-ErpObject -EntitySet "Materials" -Properties $erpMaterial
            if ($? -eq $false) {
                continue
            }
            
            Update-BomWindowEntity $entity -Status "Identical" -Properties $entity
            SetEntityProperties -erpMaterial $createErpMaterial -vaultEntity $entity
            
        }
        elseif ($entity._Status -eq "Different") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterialForUpdate -erpMaterial $erpMaterial -vaultEntity $entity
            $updateErpMaterial = Update-ERPObject -EntitySet "Materials" -Key $erpMaterial._Keys -Properties $erpMaterial._Properties
            if ($? -eq $false) {
                continue
            }
            Update-BomWindowEntity $entity -Status "Identical"
        }
        else {
            Update-BomWindowEntity $entity -Status $entity._Status
        }
    }
}

function Check-Boms($VaultBoms) {
    #Attention!!! When changing inside this function please check if you have to change somthing in "Test-ErpItemAndBOMForVaultFileOrVaultItem" function, beacause the functions are similare
    [array]::Reverse($VaultBoms)
    foreach ($vaultBom in $VaultBoms) {
  
        $number = GetEntityNumber -entity $VaultBom
        if (-not $number) {
		
            $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "There is no erp material linked to this entity!"
            foreach ($vaultBomRow in $VaultBom.Children) {
                $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "BOM head has no linked erp material!"
            }
            continue
        }
        $erpBomHeader = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows" 
        if ($? -eq $false) {
            foreach ($vaultBomRow in $VaultBom.Children) {
                $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails $vaultBOM._StatusDetails 
            }
            continue
        }

        if (-not $erpBomHeader) {
            # bomhead new
            Log -Message "Bomheader doesn't exist yet!"

            $VaultBom | Update-BomWindowEntity -Status New -StatusDetails "BOM does not exist in ERP"
            foreach ($vaultBomRow in $VaultBom.Children) {
                $childNumber = GetEntityNumber -entity $vaultBomRow
                if (-not $vaultBomRow.Bom_PositionNumber) {
                    $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "Position property is empty."
                    $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "BOM contains bomrows with a empty position property"
                    continue
                }
                $erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $childNumber.ToUpper() }
                if ($? -eq $false) {
                    $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails $vaultBomRow._StatusDetails
                    continue
                }
                if (-not $erpMaterial) {
                    # material doesn't exist yet
                    Log -Message "Error Erpmaterial doesn't exist yet! BomNumber $($childNumber)"
                    $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "Position doesn't exist as Item in ERP"
                    $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "BOM contains positions that do not exist as Items in ERP"
                }
                else {
                    $vaultBomRow | Update-BomWindowEntity -Status New -StatusDetails "Position will be added to ERP"
                }
            }
            continue
        }

        # bomhead exists
        Log -Message "Bom head exists! Check if rows need to be added/updated"

        $vaultBom | Update-BomWindowEntity -Status Identical -StatusDetails "BOM is identical between Vault and ERP"
        foreach ($vaultBomRow in $VaultBom.Children) {
            $childNumber = GetEntityNumber -entity $vaultBomRow
            if (-not $vaultBomRow.Bom_PositionNumber) {
                $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "Position property is empty."
                $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "BOM contains bomrows with a empty position property"
                continue
            }
            $erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $vaultBomRow.Bom_PositionNumber }
            if ($erpBomRow) {
                if ($vaultBomRow.Bom_Quantity -eq $erpBomRow.Quantity) {
                    $vaultBomRow | Update-BomWindowEntity -Status Identical -StatusDetails "Position is identical"
                }
                else {
                    $vaultBomRow | Update-BomWindowEntity -Status Different -StatusDetails "Quantity is different: '$($vaultBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"
                    $vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOMs are different between Vault and ERP!"      
                }

                continue
            }

            $erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $childNumber.ToUpper() }
            if ($? -eq $false) {
                $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails $vaultBomRow._StatusDetails
                continue
            }
            if (-not $erpMaterial) {
                Log -Message "Error Erpmaterial doesn't exist yet! BomNumber $($childNumber)"
                $vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "Position doesn't exist as Item in ERP"  
                $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "BOM contains positions that do not exist as Items in ERP" 
            }
            else {
                Log -Message "Bomrow is new!"
                $vaultBomRow | Update-BomWindowEntity -Status New -StatusDetails "Position will be added to ERP"  
                $vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOMs are different between Vault and ERP!" 
            }
        }
        foreach ($erpBomRow in $erpBomHeader.BomRows) {
            $vaultBomRow = $VaultBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
            if ($null -eq $vaultBomRow) {
			
                $remove = Add-BomWindowEntity -Parent $VaultBom -Type BomRow -Properties @{
                    'Part Number'        = $erpBomRow.ChildNumber
                    '_PartNumber'        = $erpBomRow.ChildNumber
                    'Name'               = $erpBomRow.ChildNumber
                    '_Name'              = $erpBomRow.ChildNumber
                    'Number'             = $erpBomRow.ChildNumber
                    '_Number'            = $erpBomRow.ChildNumber
                    'Bom_Number'         = $erpBomRow.ChildNumber
                    'Bom_Name'           = $erpBomRow.ChildNumber
                    'Bom_Quantity'       = $erpBomRow.Quantity
                    'Bom_Position'       = $erpBomRow.Position
                    'Bom_PositionNumber' = $erpBomRow.Position
                }
                Update-BomWindowEntity $remove -Status Remove -StatusDetails "Position will be deleted in ERP"
                $vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOM rows are different between Vault and ERP!" 
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
                $erpBomRow = PrepareBomRowForCreate -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $vaultBomRow
                $erpBomRows += $erpBomRow
            }
            $erpBomHeader = NewErpBomHeader
            $erpBomHeader = PrepareBomHeaderForCreate -erpBomHeader $erpBomHeader -vaultEntity $vaultBom
            $erpBomHeader.BomRows = $erpBomRows
            $erpBomHeaderResult = Add-ERPObject -EntitySet "BomHeaders" -Properties $erpBomHeader
            if ($? -eq $false) {
                foreach ($vaultBomRow in $vaultBom.Children) {
                    Update-BomWindowEntity $vaultBomRow -Status "Error" -StatusDetails $vaultBom._StatusDetails
                }
                continue
            }
            Update-BomWindowEntity $vaultBom -Status "Identical"
            foreach ($vaultBomRow in $vaultBom.Children) {
                Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""
            }

            continue
        }

        if ($vaultBom._Status -eq "Different") {
            # Status: "Unknown", "Remove", "Identical", "Error"
            $vaultBomRows = $vaultBom.Children | Sort-Object -Property _Status -Descending
            foreach ($vaultBomRow in $vaultBomRows) {

                if ($vaultBomRow._Status -eq "Remove") {
                    $removeErpBomRowResult = Remove-ERPObject -EntitySet "BomRows" -Keys @{ParentNumber = $parentNumber; ChildNumber = $vaultBomRow.Bom_Number; Position = $vaultBomRow.Bom_PositionNumber}
                    if ($? -eq $false) {
                        $vaultBom | Update-BomWindowEntity -Status 'Error' StatusDetails $vaultBomRow._StatusDetails
                    }
                    else {
                        $vaultBomRow | Remove-BomWindowEntity
                    }

                    continue
                }

                $childNumber = GetEntityNumber -entity $vaultBomRow
                if ($vaultBomRow._Status -eq "Different") {
                    $getErpBomRowResult = Get-ERPObject -EntitySet "BomRows" -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $vaultBomRow.Bom_PositionNumber } #warum wird Rückgabewert nicht verwendet? Patrick fragen.
                    if ($? -eq $false) {
                        $vaultBom | Update-BomWindowEntity -Status 'Error' -StatusDetails $vaultBomRow._StatusDetails
                        continue
                    }
                    $updateProperties = PrepareBomRowForUpdate -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $vaultBomRow
					$updateErpBomRowResult = Update-ERPObject -EntitySet "BomRows" -Keys $ErpBomRow._Keys -Properties $updateProperties
                    if ($? -eq $false) {
                        $vaultBom | Update-BomWindowEntity -Status 'Error' -StatusDetails $vaultBomRow._StatusDetails
                        continue
                    }

                    Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""

                    continue
                }

                if ($vaultBomRow._Status -eq "New") {
                    $erpBomRow = NewErpBomRow
                    $erpBomRow = PrepareBomRowForCreate -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $vaultBomRow

                    $createErpBomRowResult = Add-ERPObject -EntitySet "BomRows" -Properties $erpBomRow
                    if ($? -eq $false) {
                        $vaultBom |  Update-BomWindowEntity -Status 'Error' -StatusDetails $vaultBomRow._StatusDetails
                        continue
                    }
                    
                    Update-BomWindowEntity $vaultBomRow -Status "Identical" -StatusDetails ""
                    
                }
                else {
                    Update-BomWindowEntity $vaultBomRow -Status $vaultBomRow._Status
                }
            }
            if ($vaultBom._Status -ne "Error") {
                $vaultBom | Update-BomWindowEntity -Status 'Identical'
            }
            
        }
        else {
            # removes the dialog questionmarks for boms that are identical, Error. should be fixed in the core product! 
            Update-BomWindowEntity $vaultBom -Status $vaultBom._Status
            foreach ($vaultBomRow in $vaultBom.Children) {
                Update-BomWindowEntity $vaultBomRow -Status $vaultBomRow._Status
            }
        }
    }
}
#endregion