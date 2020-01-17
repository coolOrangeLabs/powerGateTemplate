
$materialEntitySet = "Materials"
$materialEntityType = "Material"

function GetErpMaterial($number) {
	if ([string]::IsNullOrEmpty($number)) { 
		$erpMaterial = $false
		Add-Member -InputObject $erpMaterial -Name "_ErrorMessage" -Value "Number is empty!!!" -MemberType NoteProperty -Force
		return $erpMaterial
	}
	$erpMaterial = Get-ERPObject -EntitySet $materialEntitySet -Key @{Number = $number }
	$erpMaterial = CheckResponse -entity $erpMaterial
	return $erpMaterial
}

function SearchMaterialsBase ($filter, $top = 100) {
	$erpMaterials = Get-ERPObjects -EntitySet $materialEntitySet -Filter $filter -Top $top
	$erpMaterials = CheckResponse -entity $erpMaterials
	return $erpMaterials
}

function UpdateMaterialBase($material) {
	$material = TransformMaterial -material $material
	[xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
	$mappings = Select-Xml -Xml $cfg -XPath "//VaultPropertyMappings" 
	$properties = @{ }
	foreach ($property in $material._Properties.PsObject.Properties) {
		if ($mappings.Node.ChildNodes.Key -contains $property.Name) {
			$properties.Add($property.Name, $property.Value)
		}
	}
	$updatedMaterial = Update-ERPObject -EntitySet $materialEntitySet -Key $material._Keys -Properties $properties
	$updatedMaterial = CheckResponse -entity $updatedMaterial

	return $updatedMaterial
}

function TransformMaterial($material) {
	#define here all transformations required before material creation
	$material.Number = $material.Number.ToUpper()
	$material.Description = $material.Description.ToUpper()
	#$material.DrawingNo = $material.Number
	$material.CreateDate = [DateTime]::Now
	return $material
}

function SetMaterialDefaults($material) {
	[xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
	$defValues = Select-Xml -Xml $cfg -XPath "//MaterialDefaultValues" 
	foreach ($value in $defValues.Node.ChildNodes) {
		if ($value.NodeType -eq "Comment") { continue }
		if ($material.PsObject.Properties.Name -notcontains $value.Key ) { 
			$dsDiag.Trace("property '$($value.Key)' not found on material. Check the config file")
			continue 
		}
		$dsDiag.Trace("apply default value: $($value.Key) = $($value.Value)")
		$material.$($value.Key) = $value.Value
	}
	return $material
}

function CreateMaterialBase($material) {
	#TODO: define the scenario of number generation
	# - pass number from Vault, 
	# - pass number from ERP (from another ServiceMethod)
	# - without number, ERP generates number on material creation
	if ($null -eq $material.Number -or $material.Number -eq "") {
		$material.Number = "*"
	}
	$material = TransformMaterial -material $material
	$erpMaterial = Add-ErpObject -EntitySet $materialEntitySet -Properties $material
	$erpMaterial = CheckResponse -entity $erpMaterial
	if ($erpMaterial -eq $false) {
		Show-MessageBox -message $erpMaterial._ErrorMessage -icon "Error"
	}
	return $erpMaterial
}

function NewMaterial {
	$newMaterial = New-ERPObject -EntityType $materialEntityType
	$newMaterial = SetMaterialDefaults -material $newMaterial
	return $newMaterial
}

#region user interface functions
function ActivateMaterialSection($section) {
	if ($section -eq "View") {
		$dswindow.FindName("ViewMaterial").Visibility = $visible
		$dswindow.FindName("NewMaterial").Visibility = $collapsed
	}
	elseif ($section -eq "New") {
		$dswindow.FindName("NewMaterial").Visibility = $visible
		$dswindow.FindName("ViewMaterial").Visibility = $collapsed
	}
	else {
		$dswindow.FindName("NewMaterial").Visibility = $collapsed
		$dswindow.FindName("ViewMaterial").Visibility = $collapsed
	}
}

function RegisterUiEvents {
	#TODO: define here the event for the UI
	<#
	$dsWindow.FindName("").Add_TextChanged({

	})
	#>

	$dsWindow.FindName("txtDescription").Add_TextChanged( {
			SetCreateButton
		})

	$dsWindow.FindName("MaterialTypeList").Add_SelectionChanged( {
			SetCreateButton
		})
}

function SetCreateButton {
	#TODO: define the rules for the material creation
	$material = $dsWindow.FindName("NewMaterial").DataContext
	$dsDiag.Trace($material.Type)
	$dsDiag.Trace($material.Description)
	$createButton = $false
	if ($null -ne $material.Type -and $material.Type -ne "") {
		$type = $true
	}
	if ($null -ne $material.Description -and $material.Description -ne "") {
		$description = $true
	}
	$createButton = $type -and $description
	$dsWindow.FindName("CreateMaterialButton").IsEnabled = $createButton;
}
#endregion