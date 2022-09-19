$materialEntitySet = "Materials"
$materialEntityType = "Material"

function GetEntityNumber($entity) {
	if ($entity._EntityTypeID -eq "FILE") {
		$number = $entity._PartNumber
	}
	else {
		$number = $entity._Number
	}
	return $number
}

function GetErpMaterial($number) {
	Log -Begin
	if (-not $number) {
		return @{
			Entity = $null
			ErrorMessage = "Number is empty!"
		}
	}

	$number = $number.ToUpper()
	$erpMaterial = Get-ERPObject -EntitySet $materialEntitySet -Keys @{ Number = $number }
	if($? -eq $false) {
		$message = $Error[0]#.Exception.Message
	}
	Log -End
	return @{
		Entity = $erpMaterial
		ErrorMessage = $message
	}
	
}

function NewErpMaterial {
	Log -Begin
	$erpMaterial = New-ERPObject -EntityType $materialEntityType

	#TODO: Property default values for material creation
	$erpMaterial.UnitOfMeasure = "PCS"
	$erpMaterial.Type = "Inventory"

	Log -End
	return $erpMaterial
}

function CreateErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Numbering generation for material creation (only if needed)
	if ($null -eq $erpMaterial.Number -or $erpMaterial.Number -eq "") {
		$erpMaterial.Number = "*"
	}
	#TODO: Properties that need to be set on create
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Add-ErpObject -EntitySet $materialEntitySet -Properties $erpMaterial
	$result = Get-PgsErrorForLastResponse -Entity $erpMaterial -WriteOperation
	Log -End
	return $result
}

function UpdateErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Properties that need to be set on update
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Update-ERPObject -EntitySet $materialEntitySet -Key $erpMaterial._Keys -Properties $erpMaterial._Properties
	$result = Get-PgsErrorForLastResponse -Entity $erpMaterial -WriteOperation
	Log -End
	return $result
}

function TransformErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Property transformations on create and update
	$erpMaterial.Number = $erpMaterial.Number.ToUpper()
	Log -End
	return $erpMaterial
}
function Update-VaultFileWithErrorHandling {
	param (
		$File,
		[Hashtable]$Properties
	)
	$fehler = $false
	$updatedfile = Update-VaultFile -File $File -Properties $Properties
	foreach($prop in $Properties.GetEnumerator()){
		if($updatedfile.($prop.Key) -ne ($prop.Value)){
			$fehler = $true
		}
	}
	if($fehler)
	{
		throw("Vault-File couldn't be updated!")
	}
}
function Update-VaultItemWithErrorHandling {
	param (
		$Number,
		[Hashtable]$Properties
	)
	$fehler = $false
	$updateditem = Update-VaultItem -Number $Number -Properties $Properties
	foreach($prop in $Properties.GetEnumerator()){
		if($updateditem.($prop.Key) -ne ($prop.Value)){
			$fehler = $true
		}
	}
	if($fehler)
	{
		throw("Vault-File couldn't be updated!")
	}
}
