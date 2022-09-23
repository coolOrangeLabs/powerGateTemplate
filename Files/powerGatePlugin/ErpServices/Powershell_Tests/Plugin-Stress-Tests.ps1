function Add-RandomErpObjects {
    param([int]$Amount)

    $createdMaterials = @()
    for ($i = 0; $i -lt $Amount; $i++) {
        $newMaterial = New-ERPObject -EntityType "Material" -Properties @{ 
            Number        = (Get-Date).Ticks
            Description   = "stress test"
            UnitOfMeasure = "KG"
            MaterialType  = "Alu" 
        }
        $material = Add-ERPObject -EntitySet "Materials" -Properties $newMaterial
        Write-Host "Created $($i)/$($Amount) erp item: $($material.Number)"

        $createdMaterials += @($material)
    }
    return $createdMaterials
}

function Get-MultiErpObjects {
    param($ErpItems)

    $readMaterials = @()
    foreach ($erpItem in $ErpItems) {
        $material = Get-ERPObject -EntitySet "Materials" -Keys @{
            Number = $erpItem.Number 
        }
        if (-not $material) {
            throw "failed to read erp item '($erpItem.Number)'"
        }
        else {
            Write-Host "Retrieved succesfully erp item: $($material.Number)"
            $readMaterials += @($material)
        }
    }
    return $readMaterials
}


function Get-MultiBoms {
    param($ErpBoms)

    $readBoms = @()
    foreach ($erpBom in $ErpBoms) {
        $erpBomWithChildren = Get-ERPObject -EntitySet "BomHeaders" -Keys $erpBom._Keys  -Expand @('BomRows')
        if (-not $erpBomWithChildren) {
            throw "failed to read erp item '($erpBom.Number)'"
        }
        else {
            Write-Host "Retrieved succesfully erp item: $($erpBomWithChildren.Number)"
            $readBoms += @($erpBomWithChildren)
        }
    }
    return $readBoms
}

function Update-MultiErpObjects {
    param($ErpItems)

    $updatedMaterials = @()
    foreach ($erpItem in $ErpItems) {
        $material = Update-ERPObject -EntitySet "Materials" -Keys @{
            Number = $erpItem.Number  
        } -Properties @{
            Description = "changed at (Get-Date).Ticks" 
        }
        if (-not $material) {
            throw "failed to update erp item '($erpItem.Number)'"
        }
        else {
            Write-Host "Updated succesfully erp item: $($material.Number)"
            $updatedMaterials += @($material)
        }
    }
    return $updatedMaterials
}


function Add-RandomErpBoms {
    param(
        [int]$Headers,
        $ErpItems
    )
    $erpItemsForOneBom = $ErpItems.Count / $Headers

    $createdErpBoms = @()
    for ($i = 0; $i -lt $ErpItems.Count; $i += $erpItemsForOneBom) {
        $allBomItems = $ErpItems | Select-Object -First $erpItemsForOneBom -Skip $i
        $erpHeader = $allBomItems  | Select-Object -First 1
        $erpPositions = $allBomItems  | Select-Object -Skip 1

        $bomRows = @()
        foreach ($erpPosition in $erpPositions) {
            $newBomRow = New-ERPObject -EntityType "BomRow" -Properties @{
                ParentNumber = $erpHeader.Number
                ChildNumber  = $erpPosition.Number
                Quantity     = 1
                Position     = ($bomRows.Count + 1)
            }
            $bomRows += @($newBomRow)
        }
      
        $newBom = New-ERPObject -EntityType "BomHeader" -Properties @{
            Number  = $erpHeader.Number
            BomRows = $bomRows
        }
        $bom = Add-ERPObject -EntitySet "BomHeaders" -Properties $newBom
        Write-Host "Added $($i)/$($ErpItems.Count) BOM $($bom.Number) with $($bomRows.Count) children"
        $createdErpBoms += @($bom)
    }
    return $createdErpBoms
}


function Update-MultiErpBoms {
    param(
        $ErpBoms
    )
    $updatedErpBoms = @()
    foreach ($erpBom in $ErpBoms) {

        $updatedBomHeader = Update-ERPObject -EntitySet "BomHeaders" -Keys $erpBom._Keys -Properties @{
            Description = "changed at (Get-Date).Ticks"
        }
        Write-Host "Updated erp bom header: $($updatedBomHeader.Number)"

        foreach ($erpChild in $erpBom.BomRows) {
            $updatedBomRow = Update-ERPObject -EntitySet "BomRows" -Keys $erpChild._Keys -Properties @{
                Quantity = (([int]$erpChild.Quantity) + 1)
            }
            Write-Host "Updated erp bom row: $($erpChild.ChildNumber)"
        }
        $updatedErpBoms += @($material)
    }
    return $updatedErpBoms
}

function Start-StressTest {
    $createdErpItems = Add-RandomErpObjects -Amount 100
    $allArePossibleToRead = Get-MultiErpObjects -ErpItems $createdErpItems
    $UpdatedErpItems = Update-MultiErpObjects -ErpItems $allArePossibleToRead

    $createdBoms = Add-RandomErpBoms -Headers 10 -ErpItems $createdErpItems
    $allReadBoms = Get-MultiBoms -ErpBoms $createdBoms
    $UpdatedErpBoms = Update-MultiErpBoms -ErpBoms $allReadBoms

    Write-Host "Created erp items: $($createdErpItems.Count)"
    Write-Host "Updated erp items: $($UpdatedErpItems.Count)"
    Write-Host "Succesfully retrieved erp items: $($allArePossibleToRead.Count)"
    
    Write-Host "Created erp boms: $($createdBoms.Count)"
    Write-Host "Succesfully retrieved erp boms: $($allReadBoms.Count)"
    Write-Host "Updated erp boms: $($UpdatedErpBoms.Count)"
}

Import-Module powerGate
#Disconnect-ERP -Service "http://$($ENV:Computername):8080/PGS/ErpServices"
Connect-ERP -Service "http://$($ENV:Computername):8080/PGS/ErpServices"

Start-StressTest