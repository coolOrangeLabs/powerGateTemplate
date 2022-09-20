#=============================================================================#
# PowerShell script sample for coolOrange powerEvents                         #
# Restricts the state to release, if the validation for some properties fails.#
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#

$supportedPdfExtensions = @("idw", "dwg")
$requiresErpItemExtensions = @("iam", "ipn", "ipt")

function Test-ErpItemAndBOMForVaultFileOrVaultItem {
	param(
		$Entity # Can be a powerVault File or Item
	)
	Log -Begin
	$number = GetEntityNumber -Entity $Entity
	if(-not $number) {
		Add-VaultRestriction -EntityName $number -Message "There is no erp material linked to this entity!"
	}

	$erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number.ToUpper() }
	if ($? -eq $false) {
		return
    }

	if (-not $erpMaterial) {
        Add-VaultRestriction -EntityName $number -Message "An item with the number '$($number)' does not exist in the ERP system."
		return
    }

	# ToDO: When ProAlpha is used then enable this section
	<#
	$notAllowedErpStates = @("gesperrt", "ausgelaufen")
    if ($erpMaterial.Status -in $notAllowedErpStates) {
		Add-VaultRestriction -EntityName $number -Message "In ProAlpha the status of the item is $($erpMaterial.Status) and therefore it is not allowed to change the state in Vault!"
	}
	#>

	$erpBomHeader = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows"
    if ($? -eq $false) {
        return
    }

	if (-not $erpBomHeader) {
        Log -Message "Bomheader doesn't exist yet and is new!"
		Add-VaultRestriction -EntityName $number -Message "Open the BOM Window, because the ERP BOM is different then in Vault: BOM does not exist in ERP!"
		return
    }

	Log -Message "Bom head exists! Check if rows need to be added/updated"
	$vaultBomRows = GetVaultBomRows -Entity $vaultEntity
	foreach ($vaultBomRow in $vaultBomRows) {
		$childNumber = GetEntityNumber -entity $vaultBomRow

		$erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $vaultBomRow.Bom_PositionNumber }
		if (-not $erpBomRow) {
			Add-VaultRestriction -EntityName $number -Message "Open the BOM Window, because the ERP BOM is different then in Vault!"
			return
		}
		if ($vaultBomRow.Bom_Quantity -ne $erpBomRow.Quantity) {
			Add-VaultRestriction -EntityName $number -Message "Open the BOM Window, because the ERP BOM is different then in Vault: Quantity is different: '$($vaultBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"
			return
		}
	}

	foreach ($erpBomRow in $erpBomHeader.BomRows) {
		$vaultBomRow = $VaultBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
		if (-not $vaultBomRow) {
			Add-VaultRestriction -EntityName $number -Message "Open the BOM Window, because the ERP BOM is different then in Vault!"
			return
		}
	}
	Log -End
}

Register-VaultEvent -EventName UpdateFileStates_Restrictions -Action 'RestrictFileRelease'
function RestrictFileRelease($files) {
	Log -Begin
	$defs = $vault.LifeCycleService.GetAllLifeCycleDefinitions()
	$filesToCheck = $files | Where-Object { $_._Extension -in $requiresErpItemExtensions }
	foreach ($file in $filesToCheck) {	
		$def = $defs | Where-Object { $_.DispName -eq $file._NewLifeCycleDefinition }
		$state = $def.StateArray | Where-Object { $_.DispName -eq $file._NewState }
		if ($state.ReleasedState) {
			Test-ErpItemAndBOMForVaultFileOrVaultItem -Entity $file

			# ToDO: When SAP is used with change numbers then enable the lines below, check in the function if DIR or Material is needed
			# Test-SapChangeNumbers -VaultEntity $Entity
		}
	}
	Log -End
}

Register-VaultEvent -EventName UpdateItemStates_Restrictions -Action 'RestrictItemRelease'
function RestrictItemRelease($items) {
	Log -Begin
	$defs = $vault.LifeCycleService.GetAllLifeCycleDefinitions()
	foreach ($item in $items) {
		$allItemAssociations = Get-VaultItemAssociations -Number $item._Number
		$itemIncludesFilesToCheck = $allItemAssociations | Where-Object { $_._Extension -in $script:requiresErpItemExtensions }
		$def = $defs | Where-Object { $_.DispName -eq $item._NewLifeCycleDefinition }
		$state = $def.StateArray | Where-Object { $_.DispName -eq $item._NewState }
		if ($itemIncludesFilesToCheck -and $state.ReleasedState) {
			Test-ErpItemAndBOMForVaultFileOrVaultItem -Entity $item		
		}
	}
	Log -End
}


Register-VaultEvent -EventName UpdateFileStates_Post -Action 'AddPdfJob'
function AddPdfJob($files, $successful) {
	Log -Begin
	if (-not $successful) { return }
	$releasedFiles = @($files | Where-Object { $_._Extension -in $supportedPdfExtensions -and $_._ReleasedRevision -eq $true })
	Write-Host "Found '$($releasedFiles.Count)' files which are valid to add a PDF job for!"
	foreach ($file in $releasedFiles) {
		# since Synchronize Properties gets triggered already by powerEvents, disable it in the Vault configuration!
		Write-Host "Adding job 'Synchronize Properties' for file '$($file._Name)' to queue."
		Add-VaultJob -Name "autodesk.vault.syncproperties" -Parameters @{
              "FileVersionIds"=$file.Id;
              "QueueCreateDwfJobOnCompletion"=$true} -Description "Synchronize properties of file: '$($file._Name)'"
		$jobType = "ErpService.Create.PDF"
		Write-Host "Adding job '$jobType' for file '$($file._Name)' to queue."
		Add-VaultJob -Name $jobType -Parameters @{ "EntityId" = $file.Id; "EntityClassId" = "FILE" } -Description "Create PDF for file '$($file._Name)' and upload to ERP system" -Priority 110
	}
	Log -End
}
Register-VaultEvent -EventName UpdateItemStates_Post -Action 'AddItemPdfJob'
function AddItemPdfJob($items) {
	Log -Begin
	$releasedItems = @($items | Where-Object { $_._ReleasedRevision -eq $true})
	foreach ($item in $releasedItems) {
		$jobType = "Erp.Service.CreatePDFFromItem"
		Write-Host "Adding job '$jobType' for item '$($item._Name)' to queue."
		Add-VaultJob -Name $jobType -Parameters @{ "EntityId" = $item.Id; "EntityClassId" = "ITEM" } -Description "Create PDF for item '$($item._Name)' and upload to ERP system" -Priority 101
	}
	Log -End
}