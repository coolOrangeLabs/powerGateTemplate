Import-Module powerGate
Connect-ERP -Service "http://$($ENV:Computername):8080/coolOrange/erpServices"

$material = Get-ERPObjects -EntitySet "Materials"
$material = Get-ERPObject -EntitySet "Materials" -Keys @{Number="4711"}
$newMaterial = New-ERPObject -EntityType "Material" -Properties @{ Number="4711";Description="test";UnitOfMeasure="KG";MaterialType="Alu"}
$material = Add-ERPObject -EntitySet "Materials" -Properties $newMaterial
$material = Update-ERPObject -EntitySet "Materials" -Keys @{Number="4711"} -Properties @{Description="changed"}

$bom = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number="4711"} -Expand @('BomRows')
$newBomRow = New-ERPObject -EntityType "BomRow" -Properties @{ParentNumber = "4711"; ChildNumber = "0815"; Quantity = 4.3; Position = 1}
$newBom = New-ERPObject -EntityType "BomHeader" -Properties @{Number="4711"; BomRows = @($newBomRow)}
$bom = Add-ERPObject -EntitySet "BomHeaders" -Properties $newBom