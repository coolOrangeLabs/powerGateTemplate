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

function NewErpMaterial {
	Log -Begin
	$erpMaterial = New-ERPObject -EntityType $materialEntityType

	#TODO: Property default values for material creation
	$erpMaterial.UnitOfMeasure = "PCS"
	$erpMaterial.Type = "Inventory"

	Log -End
	return $erpMaterial
}

function PrepareErpMaterialForCreate($erpMaterial, $vaultEntity) {
	Log -Begin
	$number = GetEntityNumber -entity $vaultEntity
	
	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }

	#TODO: Property mapping for material creation
	$erpMaterial.Number = $number.ToUpper()
	$erpMaterial.Description = $vaultEntity.$descriptionProp
	#TODO: Numbering generation for material creation (only if needed)
	if (-not $erpMaterial.Number) {
		$erpMaterial.Number = "*"
	}

	
	Log -End
	return $erpMaterial
}

function PrepareErpMaterialForUpdate($erpMaterial, $vaultEntity) {
	Log -Begin

	$number = GetEntityNumber -entity $vaultEntity
	
	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }
	#TODO: Properties that need to be set on update
	$erpMaterial.Number = $number.ToUpper()
	$erpMaterial.ModifiedDate = [DateTime]::Now
	$erpMaterial.Description = $vaultEntity.$descriptionProp


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
