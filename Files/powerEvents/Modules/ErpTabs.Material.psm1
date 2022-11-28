function IsEntityUnlocked($Entity) {
	if ($Entity._EntityTypeID -eq "ITEM") {
		$item = $vault.ItemService.GetLatestItemByItemMasterId($Entity.MasterId)
		$entityUnlocked = $item.Locked -ne $true
	}
	else {
		$entityUnlocked = $Entity._VaultStatus.Status.LockState -ne "Locked" -and $Entity.IsCheckedOut -ne $true
	}

	return $entityUnlocked
}

function ValidateErpMaterialTab {
	param(
		$ErpItemTab
	)

	$erpMaterial = $ErpItemTab.DataContext.ErpEntity

	if ($erpMaterial.Number) {
		$entityUnlocked = $true
	}
	else {
		$entityUnlocked = (IsEntityUnlocked -Entity $ErpItemTab.DataContext.VaultEntity)
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

	$ErpItemTab.FindName("CreateOrUpdateMaterialButton").IsEnabled = $enabled
}

function CreateOrUpdateErpMaterial {
	param($MaterialTabContext)

	if($MaterialTabContext.IsCreate) {
		$createdErpMaterial = Add-ErpObject -EntitySet "Materials" -Properties $MaterialTabContext.ErpEntity
		if ($? -eq $false) {
			return
		}

		$null = ShowMessageBox -Message "$($createdErpMaterial.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information"
		SetEntityProperties -erpMaterial $createdErpMaterial -vaultEntity $MaterialTabContext.VaultEntity

		[System.Windows.Forms.SendKeys]::SendWait("{F5}")

		return
	}

	$updatedErpMaterial = Update-ERPObject -EntitySet "Materials" -Key $MaterialTabContext.ErpEntity._Keys -Properties $MaterialTabContext.ErpEntity._Properties
	if ($? -eq $false) {
		return
	}
	$null = ShowMessageBox -Message "$($updatedErpMaterial.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information"
}

function GoToErpMaterial {
	param($MaterialTabContext)

	if ($MaterialTabContext.ErpEntity.Link) {
		Start-Process -FilePath $MaterialTabContext.ErpEntity.Link
	}
}

function LinkErpMaterial {
	param(
		$ErpItemTab
	)

	$erpMaterial = OpenErpSearchWindow
	if (-not $erpMaterial) {
		return
	}

	$vaultEntity = $ErpItemTab.DataContext.VaultEntity
	if ($vaultEntity._EntityTypeID -eq "ITEM") {
		$existingEntity = Get-VaultItem -Number $erpMaterial.Number
		if ($existingEntity) {
			if ($existingEntity.MasterId -ne $vaultEntity.MasterId) {
				$null = ShowMessageBox -Message "The ERP item $($erpMaterial.Number) cannot be assigned!`nAn item with an item number $($existingEntity._Number) already exists." -Button "Ok" -Icon "Warning"
				return
			}
		}
	}
	elseif ($vaultEntity._EntityTypeID -eq "FILE") {
		#TODO: Rename "Part Number" on a german system to "Teilenummer"
		$existingEntities = Get-VaultFiles -Properties @{"Part Number" = $erpMaterial.Number }
		if ($existingEntities) {
			$existingEntities = $existingEntities | Where-Object { $_.MasterId -ne $vaultEntity.MasterId }
			$message = ""
			if ($existingEntities) {
				$fileNames = $existingEntities._FullPath -join '`n'
				$message = "The ERP item $($erpMaterial.Number) is already assigned to `n$($fileNames).`n"
			}
		}
	}

	$answer = ShowMessageBox -Message ($message + "Do you really want to link the item '$($erpMaterial.Number)'?") -Title "powerGate ERP - Link Item" -Button "YesNo" -Icon "Question"
	if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
		SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
		$ErpItemTab.DataContext.ErpEntity = $erpMaterial
		[System.Windows.Forms.SendKeys]::SendWait("{F5}")
	}
}
