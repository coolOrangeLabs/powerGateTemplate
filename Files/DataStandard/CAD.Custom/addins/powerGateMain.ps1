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
				$null = ShowMessageBox -Message "Virtual Component '$number' successfully inserted." -Title "powerGate ERP - Virtual Component" -Icon "Information"
			}
			catch {
				$null = ShowMessageBox -Message "'$number' already exists. Please choose another ERP item." -Title "powerGate ERP - Virtual Component" -Icon "Warning"
			}
		}
		if ($prop["_FileExt"].Value -eq ".IPT") {
			$prop["Raw_Number"].Value = $number
			$prop["Raw_Quantity"].Value = 1
			$null = ShowMessageBox -Message "Raw Material '$number' successfully inserted." -Title "powerGate ERP - Raw Material" -Icon "Information"
		}
	}
}

function OpenErpMaterialWindow {
	[xml]$windowXaml = Get-Content "C:\ProgramData\coolOrange\powerGate\UI\ContainerWindow.xaml"
	$reader = (New-Object System.Xml.XmlNodeReader $windowXaml)
	$global:window = [Windows.Markup.XamlReader]::Load($reader)

	[xml]$userControlXaml = Get-Content $PSScriptRoot.Replace('\CAD.Custom\addins', '\Vault.Custom\Configuration\File\ERP Item.xaml')
	$reader = (New-Object System.Xml.XmlNodeReader $userControlXaml)
	$global:userControl = [Windows.Markup.XamlReader]::Load($reader)

	$window.FindName("ContentControl").Children.Add($userControl)
	$window.DataContext = $dsWindow.DataContext

	$userControl.DataContext = $dsWindow.DataContext

	InitErpMaterialTab -number $prop["Part Number"].Value

	if ($window.ShowDialog() -eq "OK") {
		$materialTabContext = $userControl.FindName("DataGrid").DataContext
		$erpMaterial = $materialTabContext.Entity
		$prop["Part Number"].Value = $erpMaterial.Number
	}
}

function CloseErpMaterialWindow {
	$window.DialogResult = "OK"
	$window.Close()
}

function InitErpMaterialTab($number) {
	$getErpMaterialResult = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number }

	$materialTabContext = New-Object -Type PsObject -Property @{
		Entity = $getErpMaterialResult
		IsCreate = $false
	}

	if(-not $getErpMaterialResult) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial
		$materialTabContext.IsCreate = $true
		$materialTabContext.Entity = $erpMaterial
		$goToEnabled = $false
	}
	else {
		$goToEnabled = $true
	}
	$userControl.FindName("DataGrid").DataContext = $materialTabContext
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
	}
 else {
		return $true
	}
}

function ValidateErpMaterialTab {
	$materialTabContext = $userControl.FindName("DataGrid").DataContext
	$erpMaterial = $materialTabContext.Entity
	if ($erpMaterial.Number) {
		$entityUnlocked = $true
	}
	else {
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
	$materialTabContext = $userControl.FindName("DataGrid").DataContext

	if($materialTabContext.IsCreate) {
		$createErpMaterialResult = Add-ErpObject -EntitySet "Materials" -Properties $materialTabContext.Entity
		if ($? -eq $false) {
			return
		}
		$null = ShowMessageBox -Message "$($createErpMaterialResult.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information"
		SetEntityProperties -erpMaterial $createErpMaterialResult
	}
	else {
		$updateErpMaterialResult = Update-ERPObject -EntitySet "Materials" -Key $materialTabContext.Entity._Keys -Properties $materialTabContext.Entity._Properties
        if ($? -eq $false) {
            return
        }
		$null = ShowMessageBox -Message "$($updateErpMaterialResult.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information"
	}

	RefreshView
}

function GoToErpMaterial {
	$materialTabContext = $userControl.FindName("DataGrid").DataContext
	$erpMaterial = $materialTabContext.Entity
	if ($erpMaterial.Link) {
		Start-Process -FilePath $erpMaterial.Link
	}
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow

	#TODO: Rename "Part Number" on a german system to "Teilenummer"
	$existingEntities = Get-VaultFiles -Properties @{"Part Number" = $erpMaterial.Number }
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

############################



function InitializeWindow
{
	Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
	Initialize-CoolOrange

	$erpServices = Get-ERPServices -Available
	if (-not $erpServices -or $erpServices.Count -le 0) {
		$dswindow.FindName("lblStatusMessage").Content = "One or more services are not available!"
		$dswindow.FindName("lblStatusMessage").Foreground = "Red"
		$dsWindow.FindName("powerGateGrid").IsEnabled = $false
	}

	$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Inventor-powerGate.log"
	Set-LogFilePath -Path $logPath
	#begin rules applying commonly
    $dsWindow.Title = SetWindowTitle
    InitializeCategory
    InitializeNumSchm
    InitializeBreadCrumb
    InitializeFileNameValidation
	#end rules applying commonly
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"InventorWindow"
		{
			#rules applying for Inventor
		}
		"AutoCADWindow"
		{
			#rules applying for AutoCAD
		}
	}
	$global:expandBreadCrumb = $true
}

function AddinLoaded
{
	#Executed when DataStandard is loaded in Inventor/AutoCAD
}

function AddinUnloaded
{
	#Executed when DataStandard is unloaded in Inventor/AutoCAD
}

function InitializeCategory()
{
    if ($Prop["_CreateMode"].Value)
    {
		if (-not $Prop["_SaveCopyAsMode"].Value)
		{
            $Prop["_Category"].Value = $UIString["CAT1"]
        }
    }
}

function InitializeNumSchm()
{
	#Adopted from a DocumentService call, which always pulls FILE class numbering schemes
	$global:numSchems = @($vault.NumberingService.GetNumberingSchemes('FILE', 'Activated'))
    if ($Prop["_CreateMode"].Value)
    {
		if (-not $Prop["_SaveCopyAsMode"].Value)
		{
			$Prop["_Category"].add_PropertyChanged({
				if ($_.PropertyName -eq "Value")
				{
					$numSchm = $numSchems | where {$_.Name -eq $Prop["_Category"].Value}
                    if($numSchm)
					{
                        $Prop["_NumSchm"].Value = $numSchm.Name
                    }
				}
			})
        }
		else
        {
            $Prop["_NumSchm"].Value = "None"
        }
    }
}

function GetVaultRootFolder()
{
    $mappedRootPath = $Prop["_VaultVirtualPath"].Value + $Prop["_WorkspacePath"].Value
    $mappedRootPath = $mappedRootPath -replace "\\", "/" -replace "//", "/"
    if ($mappedRootPath -eq '')
    {
        $mappedRootPath = '$'
    }
    return $vault.DocumentService.GetFolderByPath($mappedRootPath)
}

function SetWindowTitle
{
	$mWindowName = $dsWindow.Name
    switch($mWindowName)
 	{
  		"InventorFrameWindow"
  		{
   			$windowTitle = $UIString["LBL54"]
  		}
  		"InventorDesignAcceleratorWindow"
  		{
   			$windowTitle = $UIString["LBL50"]
  		}
  		"InventorPipingWindow"
  		{
   			$windowTitle = $UIString["LBL39"]
  		}
  		"InventorHarnessWindow"
  		{
   			$windowTitle = $UIString["LBL44"]
  		}
  		default #applies to InventorWindow and AutoCADWindow
  		{
   			if ($Prop["_CreateMode"].Value)
   			{
    			if ($Prop["_CopyMode"].Value)
    			{
     				$windowTitle = "$($UIString["LBL60"]) - $($Prop["_OriginalFileName"].Value)"
    			}
    			elseif ($Prop["_SaveCopyAsMode"].Value)
    			{
     				$windowTitle = "$($UIString["LBL72"]) - $($Prop["_OriginalFileName"].Value)"
    			}else
    			{
     				$windowTitle = "$($UIString["LBL24"]) - $($Prop["_OriginalFileName"].Value)"
    			}
   			}
   			else
   			{
    			$windowTitle = "$($UIString["LBL25"]) - $($Prop["_FileName"].Value)"
   			}
  		}
 	}
  	return $windowTitle
}

function GetNumSchms
{
	$specialFiles = @(".DWG",".IDW",".IPN")
    if ($specialFiles -contains $Prop["_FileExt"].Value -and !$Prop["_GenerateFileNumber4SpecialFiles"].Value)
    {
        return $null
    }
	if (-Not $Prop["_EditMode"].Value)
    {
        if ($numSchems.Count -gt 1)
		{
			$numSchems = $numSchems | Sort-Object -Property IsDflt -Descending
		}
        if ($Prop["_SaveCopyAsMode"].Value)
        {
            $noneNumSchm = New-Object 'Autodesk.Connectivity.WebServices.NumSchm'
            $noneNumSchm.Name = $UIString["LBL77"]
            return $numSchems += $noneNumSchm
        }
        return $numSchems
    }
}

function GetCategories
{
	return $Prop["_Category"].ListValues
}

function OnPostCloseDialog
{
	$mWindowName = $dsWindow.Name
	switch($mWindowName)
	{
		"InventorWindow"
		{
			#rules applying for Inventor
		}
		"AutoCADWindow"
		{
			#rules applying for AutoCAD
		}
		default
		{
			#rules applying commonly
		}
	}
}