$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"

#region BOM Header
function GetErpBomHeader($number) {
	Log -Begin
	$erpBomHeader = Get-ERPObject -EntitySet $bomHeaderEntitySet -Keys @{Number = $number } -Expand "BomRows"
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
}

function NewErpBomHeader {
	Log -Begin
	$erpBomHeader = New-ErpObject -EntityType $bomHeaderEntityType
	Log -End
	return $erpBomHeader
}

function CreateErpBomHeader($erpBomHeader) {
	Log -Begin
	#TODO: Property manipulation for bom header create
	$erpBomHeader.ModifiedDate = [DateTime]::Now

	$erpBomHeader = Add-ERPObject -EntitySet $bomHeaderEntitySet -Properties $erpBomHeader
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
}

function UpdateErpBomHeader($erpBomHeader) {
	Log -Begin
	#TODO: Property manipulation for bom header update
	$erpBomHeader.ModifiedDate = [DateTime]::Now

	$erpBomHeader = Update-ERPObject -EntitySet $bomHeaderEntitySet -keys $erpBomHeader._Keys -Properties $erpBomHeader._Properties
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
}
#endregion

#region BOM Row
function GetErpBomRow($parentNumber, $childNumber, $position) {
	Log -Begin
	$erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}

function NewErpBomRow {
	Log -Begin
	$erpBomRow = New-ErpObject -EntityType $bomRowEntityType
	Log -End
	return $erpBomRow
}

function CreateErpBomRow($erpBomRow) {
	Log -Begin
	#TODO: Property manipulation for bom row create
	$erpBomRow.ModifiedDate = [DateTime]::Now

	$erpBomRow = Add-ERPObject -EntitySet $bomRowEntitySet -Properties $erpBomRow
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}

function UpdateErpBomRow($erpBomRow) {
	Log -Begin
	#TODO: Property manipulation for bom row update
	$erpBomRow.ModifiedDate = [DateTime]::Now

	$erpBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -Keys $erpBomRow._Keys -Properties @{Quantity = $erpBomRow.Quantity }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}

function RemoveErpBomRow($parentNumber, $childNumber, $position) {
	Log -Begin
	$erpBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}
#endregion