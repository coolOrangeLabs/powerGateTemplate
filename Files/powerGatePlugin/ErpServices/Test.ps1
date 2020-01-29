Import-Module powerGate
#Disconnect-ERP -Service "http://$($ENV:Computername):8080/coolOrange/ErpServices"
Connect-ERP -Service "http://$($ENV:Computername):8080/coolOrange/ErpServices"

$materials = Get-ERPObjects -EntitySet "Materials"
$material = Get-ERPObject -EntitySet "Materials" -Keys @{Number="4711"}
$newMaterial = New-ERPObject -EntityType "Material" -Properties @{ Number="4711";Description="test";UnitOfMeasure="KG";MaterialType="Alu"}
$material = Add-ERPObject -EntitySet "Materials" -Properties $newMaterial
$material = Update-ERPObject -EntitySet "Materials" -Keys @{Number="4711"} -Properties @{Description="changed"}

$bom = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number="4711"} -Expand @('BomRows')
$newBomRow = New-ERPObject -EntityType "BomRow" -Properties @{ParentNumber = "4711"; ChildNumber = "0815"; Quantity = 4.3; Position = 1}
$newBom = New-ERPObject -EntityType "BomHeader" -Properties @{Number="4711"; BomRows = @($newBomRow)}
$bom = Add-ERPObject -EntitySet "BomHeaders" -Properties $newBom

$d = New-ERPObject -EntityType "Document"
$d.Number = "0816"
$d.Description = "Description"
$d.FileName = "Blower.idw.pdf"
Add-ERPMedia -EntitySet "Documents" -Properties $d -ContentType "application/pdf" -File "C:\TEMP\Blower.idw.pdf"

$document = Get-ERPObject -EntitySet "Documents" -Keys @{Number="0816"}
Get-ERPMedia -EntitySet "Documents" -Keys @{Number="0816"} -File "C:\TEMP\Download.pdf"
