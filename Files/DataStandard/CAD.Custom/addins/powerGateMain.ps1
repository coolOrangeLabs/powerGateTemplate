$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
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
	[xml]$windowXaml = Get-Content "C:\ProgramData\coolOrange\powerGate\UI\ContainerWindow.xaml"
	$reader=(New-Object System.Xml.XmlNodeReader $windowXaml)
	$global:window=[Windows.Markup.XamlReader]::Load($reader)	

	[xml]$userControlXaml = Get-Content $PSScriptRoot.Replace('\CAD.Custom\addins', '\Vault.Custom\Configuration\File\erpItem.xaml')
	$reader=(New-Object System.Xml.XmlNodeReader $userControlXaml)
	$global:userControl=[Windows.Markup.XamlReader]::Load($reader)

	$window.FindName("ContentControl").Children.Add($userControl)
	$window.DataContext = $dsWindow.DataContext
	$userControl.DataContext = $dsWindow.DataContext
	
	InitErpMaterialTab -number $prop["Part Number"].Value

	if ($window.ShowDialog() -eq "OK") {
		$erpMaterial = $userControl.FindName("DataGrid").DataContext
		$prop["Part Number"].Value = $erpMaterial.Number
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
	$erpMaterial.Description = $prop["Description"].Value

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
		SetEntityProperties -erpMaterial $erpMaterial
		InitErpMaterialTab -number $erpMaterial.Number
	}
}


function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow
	# TODO:  Rename "Part Number" on a german system to "Teilenummer"
	$entitesWithSameErpMaterial = Search-EntitiesByPropertyValue -EntityClassId "FILE" -PropertyName "Part Number" -SearchValue $ErpMaterial.Number -SearchCondition "IsExactly"
	if($entitesWithSameErpMaterial) {
		$entityNames = $entitesWithSameErpMaterial | Select-Object -ExpandProperty @("_FullPath")
		([System.Windows.Forms.MessageBox]::Show("The ERP item '$($erpMaterial.Number)' is already linked to other files: `n $entityNames", "ERP Item is already used in Vault", "Ok", "Warning")	) | Out-Null
		return;
	}
    if ($erpMaterial) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Do you really want to link the item '$($erpMaterial.Number)'?", "Link ERP Item", "YesNo", "Question")	
        if ($answer -eq "Yes") {
            SetEntityProperties -erpMaterial $erpMaterial
			RefreshView
            #[System.Windows.Forms.MessageBox]::Show("The object has been linked")
        }       
    }
}

function SetEntityProperties($erpMaterial) {
	#TODO: Update Inventor iProperties with values from ERP
	$prop["Part Number"].Value = $erpMaterial.Number
	$prop["Description"].Value = $erpMaterial.Description
}