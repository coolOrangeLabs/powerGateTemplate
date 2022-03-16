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

function GetErpMaterialWithPGError($number) {
	Log -Begin
	$erpMaterialHashtable = @{
		Entity = $null;
		ErrorMessage = $null
	}
	if (-not $number) { 
		$erpMaterialHashtable.Entity = $null
		erpMaterialHashtable.ErrorMessage = "Number is empty!"
		return $erpMaterialHashtable
	}
	$number = $number.ToUpper()
	$erpMaterial = Get-ERPObject -EntitySet $materialEntitySet -Keys @{ Number = $number }
	$erpMaterialHashtable = Edit-ResponseWithErrorMessage -Entity $erpMaterial
	
	Add-Member -InputObject $erpMaterialHashtable.Entity -Name "IsCreate" -Value $false -MemberType NoteProperty -Force
	Add-Member -InputObject $erpMaterialHashtable.Entity -Name "IsUpdate" -Value $true -MemberType NoteProperty -Force	
	Log -End
	return $erpMaterialHashtable
}

function NewErpMaterial {
	Log -Begin
	$erpMaterial = New-ERPObject -EntityType $materialEntityType

	#TODO: Property default values for material creation
	$erpMaterial.UnitOfMeasure = "PCS"
	$erpMaterial.Type = "Inventory"

	Add-Member -InputObject $erpMaterial -Name "IsCreate" -Value $true -MemberType NoteProperty -Force
	Add-Member -InputObject $erpMaterial -Name "IsUpdate" -Value $false -MemberType NoteProperty -Force
	Log -End
	return $erpMaterial
}

function CreateErpMaterialWithPGError($erpMaterial) {
	Log -Begin
	#TODO: Numbering generation for material creation (only if needed)
	if ($null -eq $erpMaterial.Number -or $erpMaterial.Number -eq "") {
		$erpMaterial.Number = "*"
	}
	#TODO: Properties that need to be set on create
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial.PSObject.Properties.Remove('IsCreate')
	$erpMaterial.PSObject.Properties.Remove('IsUpdate')

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Add-ErpObject -EntitySet $materialEntitySet -Properties $erpMaterial
	$erpMaterialHashtable = Edit-ResponseWithErrorMessage -Entity $erpMaterial -WriteOperation
	Log -End
	return $erpMaterialHashtable
}

function UpdateErpMaterialWithPGError($erpMaterial) {
	Log -Begin
	#TODO: Properties that need to be set on update
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Update-ERPObject -EntitySet $materialEntitySet -Key $erpMaterial._Keys -Properties $erpMaterial._Properties
	$erpMaterialHashtable = Edit-ResponseWithErrorMessage -Entity $erpMaterial -WriteOperation
	Log -End
	return $erpMaterialHashtable
}

function TransformErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Property transformations on create and update
	$erpMaterial.Number = $erpMaterial.Number.ToUpper()
	Log -End
	return $erpMaterial
}
