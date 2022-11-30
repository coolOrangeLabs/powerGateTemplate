function CanCreateOrUpdateErpMaterial {
	param(
		$erpMaterial
	)

	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	if ($null -ne $erpMaterial.Type -and $erpMaterial.Type -ne "") {
		$type = $true
	}
	if ($null -ne $erpMaterial.Description -and $erpMaterial.Description -ne "") {
		$description = $true
	}
	return $type -and $description
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
