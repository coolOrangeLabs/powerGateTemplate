
$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"



function GetBomHeader($number) {
	$erpBomHeader = Get-ERPObject -EntitySet $bomHeaderEntitySet -Keys @{Number=$number} -Expand "BomRows"
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	return $erpBomHeader
}

function GetBomRow($parentNumber,$childNumber,$position) {
	$erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber=$parentNumber;ChildNumber=$childNumber;Position=$position}
	$erpBomRow = CheckResponse -entity $erpBomRow
	return $erpBomRow
}

function NewBomRow
{
	$newBomRow = New-ErpObject -EntityType $bomRowEntityType
	$newBomRow = SetBomRowDefaults -BomRow $newBomRow
	return $newBomRow
}

function NewBomHeader
{
	$newBomHeader = New-ErpObject -EntityType $bomHeaderEntityType
	$newBomHeader = SetBomHeaderDefaults -bomHeader $newBomHeader
	return $newBomHeader
}

function CreateBomHeader($newBomHeader) {
	$newBomHeader = Add-ERPObject -EntitySet $bomHeaderEntitySet -Properties $newBomHeader
	$newBomHeader = CheckResponse -entity $newBomHeader
	return $newBomHeader
}

function CreateBomRow($newBomRow) {
	$newBomRow = Add-ERPObject -EntitySet $bomRowEntitySet -Properties $newBomRow
	$newBomRow = CheckResponse -entity $newBomRow
	return $newBomRow
}

function UpdateBomRow($updateBomRow) {
	$updateBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -keys $updateBomRow._Keys -Properties @{Quantity=$updateBomRow.Quantity}
	$updateBomRow = CheckResponse -entity $updateBomRow
	return $updateBomRow
}

function RemoveBomRow($parentNumber, $childNumber, $position) {
	$removeBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -keys @{ParentNumber=$parentNumber;ChildNumber=$childNumber;Position=$position}
	$removeBomRow = CheckResponse -entity $removeBomRow
	return $removeBomRow
}

function SetBomHeaderDefaults($bomHeader)
{
	[xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    $defValues = Select-Xml -Xml $cfg -XPath "//BomHeaderDefaultValues" 
	foreach($value in $defValues.Node.ChildNodes){
		if($value.NodeType -eq "Comment") { continue }
		if($bomHeader.PsObject.Properties.Name -notcontains $value.Key ) { 
			$dsDiag.Trace("property '$($value.Key)' not found on BOM Header. Check the config file")
			continue 
		}
		$dsDiag.Trace("apply default value: $($value.Key) = $($value.Value)")
		$bomHeader.$($value.Key) = $value.Value
	}
	return $bomHeader
}

function SetBomRowDefaults($bomRow)
{
	[xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    $defValues = Select-Xml -Xml $cfg -XPath "//BomRowDefaultValues" 
	foreach($value in $defValues.Node.ChildNodes){
		if($value.NodeType -eq "Comment") { continue }
		if($bomRow.PsObject.Properties.Name -notcontains $value.Key ) { 
			$dsDiag.Trace("property '$($value.Key)' not found on BOM Row. Check the config file")
			continue 
		}
		$dsDiag.Trace("apply default value: $($value.Key) = $($value.Value)")
		$bomRow.$($value.Key) = $value.Value
	}
	return $bomRow
}

