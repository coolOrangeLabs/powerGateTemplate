$commonModulePath = $PSScriptRoot.Replace('\CAD.Custom\addins', '\powerGateModules')
$modules = Get-ChildItem -path $commonModulePath -Filter *.psm1
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }	

ConnectToErpServer

function OpenErpInsertWindow {
	#TODO: Show Search dialog to get item number
	$erpMaterial = OpenErpSearchWindow
    if ($erpMaterial) {
        $number = $erpMaterial.Number
		if ($prop["_FileExt"].Value -eq ".IAM") {
			try {
				$matrix = $Application.TransientGeometry.CreateMatrix()
				$occur = $Document.ComponentDefinition.Occurrences
				$occur.AddVirtual($number, $matrix)
				Show-MessageBox -message "Virtual Component '$number' successfully inserted." -title "powerGate ERP - Virtual Component" -icon "Information"
			} catch {
				Show-MessageBox -message "'$number' already exists. Please choose another ERP item." -title "powerGate ERP - Virtual Component" -icon "Warning"
			}
		}
		if ($prop["_FileExt"].Value -eq ".IPT") {
			$prop["Raw_Number"].Value = $number
			$prop["Raw_Quantity"].Value = 1
			Show-MessageBox -message "Raw Material '$number' successfully inserted." -title "powerGate ERP - Raw Material" -icon "Information"
		}     
    }
}

function OpenErpMaterialWindow {
	[xml]$windowXaml = Get-Content "C:\ProgramData\Autodesk\Vault 2020\Extensions\DataStandard\CAD.Custom\Configuration\erpItemWindow.xaml"
	$reader=(New-Object System.Xml.XmlNodeReader $windowXaml)
	$global:window=[Windows.Markup.XamlReader]::Load($reader)	
	
	[xml]$userControlXaml = Get-Content "C:\ProgramData\Autodesk\Vault 2020\Extensions\DataStandard\Vault.Custom\Configuration\File\erpItem.xaml"
	$reader=(New-Object System.Xml.XmlNodeReader $userControlXaml)
	$global:userControl=[Windows.Markup.XamlReader]::Load($reader)

	$window.FindName("ContentControl").Children.Add($userControl)
	$window.DataContext = $dsWindow.DataContext
	$userControl.DataContext = $dsWindow.DataContext
	
	InitErpMaterialTab -number $prop["Part Number"].Value

	if ($window.ShowDialog() -eq "OK") {
		$prop["Part Number"].Value = $userControl.FindName("DataGrid").DataContext.Number
		#TODO: Write back properties from ERP to iProperties (if needed)
	}
}

function CloseErpMaterialWindow {
	$window.DialogResult = "OK"
	$window.Close()
}

function InitErpMaterialTab($number) {
	$erpMaterial = GetErpMaterial -number $number
	if (-not $erpMaterial) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial
	}
	$userControl.FindName("DataGrid").DataContext = $erpMaterial
}

function PrepareErpMaterial($erpMaterial) {
	#TODO: Property mapping for material creation
	$erpMaterial.Number = $prop["Part Number"].Value
	$erpMaterial.Description = $prop["Title"].Value

	return $erpMaterial
}

function ValidateErpMaterialTab {
	$erpMaterial = $userControl.FindName("DataGrid").DataContext
	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	$enabled = $false
	if ($null -ne $erpMaterial.Type -and $erpMaterial.Type -ne "") {
		$type = $true
	}
	if ($null -ne $erpMaterial.Description -and $erpMaterial.Description -ne "") {
		$description = $true
	}
	$enabled = $type -and $description
	$userControl.FindName("CreateOrUpdateMaterialButton").IsEnabled = $enabled
}

function CreateOrUpdateErpMaterial {
	$erpMaterial = $userControl.FindName("DataGrid").DataContext
	if ($erpMaterial.IsUpdate) {
		$erpMaterial = UpdateErpMaterial -erpMaterial $erpMaterial
		if ($erpMaterial) { 
			Show-MessageBox -message "Update successful" -icon "Information"
		} else { 
			Show-MessageBox -message $erpMaterial._ErrorMessage -icon "Error" -title "ERP material update error"
		}
	} else {
		$erpMaterial = CreateErpMaterial -erpMaterial $erpMaterial
		InitErpMaterialTab -number $erpMaterial.Number
	}
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow
    if ($erpMaterial) {
        $number = $erpMaterial.Number
        $answer = [System.Windows.Forms.MessageBox]::Show("Do you really want to link the item '$number'?", "Link ERP Item", "YesNo", "Question")	
        if ($answer -eq "Yes") {
			$prop["Part Number"].Value = $number
			InitErpMaterialTab -number $erpMaterial.Number
        }       
    }
}