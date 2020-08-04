$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Recurse -Filter *.ps*
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }	
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Inventor-powerGate.txt"

ConnectToErpServerWithMessageBox

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
				ShowMessageBox -Message "Virtual Component '$number' successfully inserted." -Title "powerGate ERP - Virtual Component" -Icon "Information" | Out-Null
			} catch {
				ShowMessageBox -Message "'$number' already exists. Please choose another ERP item." -Title "powerGate ERP - Virtual Component" -Icon "Warning"  | Out-Null
			}
		}
		if ($prop["_FileExt"].Value -eq ".IPT") {
			$prop["Raw_Number"].Value = $number
			$prop["Raw_Quantity"].Value = 1
			ShowMessageBox -Message "Raw Material '$number' successfully inserted." -Title "powerGate ERP - Raw Material" -Icon "Information" | Out-Null
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
	if (-not $erpMaterial -or $false -eq $erpMaterial) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial
		$goToEnabled = $false
	} else {
		$goToEnabled = $true
	}
	$userControl.FindName("DataGrid").DataContext = $erpMaterial
	$userControl.FindName("LinkMaterialButton").IsEnabled = IsEntityUnlocked
	$userControl.FindName("GoToMaterialButton").IsEnabled = $goToEnabled
}

function PrepareErpMaterial($erpMaterial) {
	#TODO: Property mapping for material creation
	$erpMaterial.Number = $prop["Part Number"].Value
	$erpMaterial.Description = $prop["Description"].Value

	return $erpMaterial
}

function IsEntityUnlocked {
	$fullFileName = $prop["_FilePath"].Value + "\" + $prop["_FileName"].Value
	if (Test-Path -Path $fullFileName) {
		$status = Get-ChildItem $fullFileName
		return (-not $status.IsReadOnly)		
	} else {
		return $true
	}
}

function ValidateErpMaterialTab {
	$erpMaterial = $userControl.FindName("DataGrid").DataContext
	if ($erpMaterial.Number) {
		$entityUnlocked = $true
	} else {
		$entityUnlocked = IsEntityUnlocked
	}

	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	$enabled = $false
	if ($null -ne $erpMaterial.Type -and $erpMaterial.Type -ne "") {
		$type = $true
	}
	if ($null -ne $erpMaterial.Description -and $erpMaterial.Description -ne "") {
		$description = $true
	}
	$enabled = $entityUnlocked -and $type -and $description
	$userControl.FindName("CreateOrUpdateMaterialButton").IsEnabled = $enabled
}

function CreateOrUpdateErpMaterial {
	$erpMaterial = $userControl.FindName("DataGrid").DataContext
	if ($erpMaterial.IsUpdate) {
		$erpMaterial = UpdateErpMaterial -erpMaterial $erpMaterial
		if (-not $erpMaterial -or $false -eq $erpMaterial) { 	
			ShowMessageBox -Message $erpMaterial._ErrorMessage -Icon "Error" -Title "powerGate ERP - Update Material" | Out-Null
		} else { 
			ShowMessageBox -Message "$($erpMaterial.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information"  | Out-Null
		}
	} else {
		$erpMaterial = CreateErpMaterial -erpMaterial $erpMaterial
		if (-not $erpMaterial -or $false -eq $erpMaterial) { 	
			ShowMessageBox -Message $erpMaterial._ErrorMessage -Icon "Error" -Title "powerGate ERP - Create Material" | Out-Null
		} else { 
			ShowMessageBox -Message "$($erpMaterial.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information"  | Out-Null
			SetEntityProperties -erpMaterial $erpMaterial
			#InitErpMaterialTab -number $erpMaterial.Number
		}
	}
	RefreshView
}

function GoToErpMaterial {
	$erpMaterial = $userControl.FindName("DataGrid").DataContext
	if ($erpMaterial.Link) {
		Start-Process -FilePath $erpMaterial.Link
	}
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow

	#TODO: Rename "Part Number" on a german system to "Teilenummer"
	$existingEntities = Get-VaultFiles -Properties @{"Part Number" = $erpMaterial.Number}
	if ($existingEntities) {
		$message = ""
		#$existingEntities = $existingEntities | Where-Object { $_.MasterId -ne $vaultEntity.MasterId }
		if ($existingEntities) {
			$fileNames = $existingEntities._FullPath -join '`n'
			$message = "The ERP item $($erpMaterial.Number) is already assigned to `n$($fileNames).`n"
		}
	}

	$answer = ShowMessageBox -Message ($message + "Do you really want to link the item '$($erpMaterial.Number)'?") -Title "powerGate ERP - Link Item" -Button "YesNo" -Icon "Question"
	if ($answer -eq "Yes") {
		SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
		RefreshView
	}
}

function RefreshView {
	[System.Windows.Forms.SendKeys]::SendWait("{F5}") 
	InitErpMaterialTab -number $prop["Part Number"].Value
}

function SetEntityProperties($erpMaterial) {
	#TODO: Update Inventor iProperties with values from ERP
	$prop["Part Number"].Value = $erpMaterial.Number
	$prop["Description"].Value = $erpMaterial.Description
}