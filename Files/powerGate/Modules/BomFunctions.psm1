$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"

#region BOM Header
function GetErpBomHeader($number) {
	$erpBomHeader = Get-ERPObject -EntitySet $bomHeaderEntitySet -Keys @{Number = $number } -Expand "BomRows"
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	return $erpBomHeader
}

function NewErpBomHeader {
	$erpBomHeader = New-ErpObject -EntityType $bomHeaderEntityType
	return $erpBomHeader
}

function CreateErpBomHeader($erpBomHeader) {
	#TODO: Property manipulation for bom header create
	$erpBomHeader.ModifiedDate = [DateTime]::Now

	$erpBomHeader = Add-ERPObject -EntitySet $bomHeaderEntitySet -Properties $erpBomHeader
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	return $erpBomHeader
}

function UpdateErpBomHeader($erpBomHeader) {
	#TODO: Property manipulation for bom header update
	$erpBomHeader.ModifiedDate = [DateTime]::Now

	$erpBomHeader = Update-ERPObject -EntitySet $bomHeaderEntitySet -keys $erpBomHeader._Keys -Properties $erpBomHeader._Properties
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	return $erpBomHeader
}
#endregion

#region BOM Row
function GetErpBomRow($parentNumber, $childNumber, $position) {
	$erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	return $erpBomRow
}

function NewErpBomRow {
	$erpBomRow = New-ErpObject -EntityType $bomRowEntityType
	return $erpBomRow
}

function CreateErpBomRow($erpBomRow) {
	#TODO: Property manipulation for bom row create
	$erpBomRow.ModifiedDate = [DateTime]::Now

	$erpBomRow = Add-ERPObject -EntitySet $bomRowEntitySet -Properties $erpBomRow
	$erpBomRow = CheckResponse -entity $erpBomRow
	return $erpBomRow
}

function UpdateErpBomRow($erpBomRow) {
	#TODO: Property manipulation for bom row update
	$erpBomRow.ModifiedDate = [DateTime]::Now

	$erpBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -Keys $erpBomRow._Keys -Properties @{Quantity = $erpBomRow.Quantity }
	$erpBomRow = CheckResponse -entity $erpBomRow
	return $erpBomRow
}

function RemoveErpBomRow($parentNumber, $childNumber, $position) {
	$erpBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	return $erpBomRow
}
#endregion