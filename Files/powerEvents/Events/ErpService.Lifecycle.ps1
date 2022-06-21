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

function Test-ErpItemForVaultFileOrVaultItem {
	param(
		$Entity # Can be a powerVault FILE or Vault object
	)
	Log -Begin
	$entityNumber = GetEntityNumber -Entity $Entity

	$getErpMaterialResult = GetErpMaterial -Number $entityNumber
	try {
		Test-ErpItemExists -ErpMaterial $getErpMaterialResult.Entity -VaultEntity $Entity
		
		# ToDO: When ProAlpha is used then enable this line
		# Test-ProAlphaStatusIsOk -ErpMaterial $getErpMaterialResult.Entity
		
		Test-ErpBomIsSynced -Entity $Entity
	}
	catch {
		$restrictMessage = "$($_)"
		Add-VaultRestriction -EntityName $entityNumber -Message $restrictMessage
	}
	Log -End
}

Register-VaultEvent -EventName UpdateFileStates_Restrictions -Action 'RestrictFileRelease'
function RestrictFileRelease($files) {
	Log -Begin
	try {
		$defs = $vault.LifeCycleService.GetAllLifeCycleDefinitions()
		$filesToCheck = $files | Where-Object { $_._Extension -in $requiresErpItemExtensions }
		foreach ($file in $filesToCheck) {	
			$def = $defs | Where-Object { $_.DispName -eq $file._NewLifeCycleDefinition }
			$state = $def.StateArray | Where-Object { $_.DispName -eq $file._NewState }
			if ($state.ReleasedState) {
				Test-ErpItemForVaultFileOrVaultItem -Entity $file

				# ToDO: When SAP is used with change numbers then enable the lines below, check in the function if DIR or Material is needed
				# Test-SapChangeNumbers -VaultEntity $Entity
			}
		}
	}
 catch {
		#Show-Inspector
		Write-Error -Message $_.Exception.Message
		ShowMessageBox -Message $_.Exception.Message -Icon Error
	}
 finally {		
		Log -End
	}
}

Register-VaultEvent -EventName UpdateItemStates_Restrictions -Action 'RestrictItemRelease'
function RestrictItemRelease($items) {
	Log -Begin
	try {
		$defs = $vault.LifeCycleService.GetAllLifeCycleDefinitions()
		foreach ($item in $items) {
			$allItemAssociations = Get-VaultItemAssociations -Number $item._Number
			$itemIncludesFilesToCheck = $allItemAssociations | Where-Object { $_._Extension -in $script:requiresErpItemExtensions }
			$def = $defs | Where-Object { $_.DispName -eq $item._NewLifeCycleDefinition }
			$state = $def.StateArray | Where-Object { $_.DispName -eq $item._NewState }
			if ($itemIncludesFilesToCheck -and $state.ReleasedState) {
				Test-ErpItemForVaultFileOrVaultItem -Entity $item		
			}
		}
	}
	catch {
		Write-Error -Message $_.Exception.Message
		ShowMessageBox -Message $_.Exception.Message -Icon Error
	}
 finally {		
		Log -End
	}
}


Register-VaultEvent -EventName UpdateFileStates_Post -Action 'AddPdfJob'
function AddPdfJob($files, $successful) {
	Log -Begin
	try {
		if (-not $successful) { return }
		$releasedFiles = @($files | Where-Object { $_._Extension -in $supportedPdfExtensions -and $_._ReleasedRevision -eq $true })
		Write-Host "Found '$($releasedFiles.Count)' files which are valid to add a PDF job for!"
		foreach ($file in $releasedFiles) {
			Import-Module "C:\ProgramData\coolOrange\powerEvents\Modules\coolOrange.Queue.ADSKJobs.psm1"
			Write-Host "Adding job 'Synchronize Properties' for file '$($file._Name)' to queue."
			QueuePropSyncJob -File $file -Priority 100 | Out-Null
			$jobType = "ErpService.Create.PDF"
			Write-Host "Adding job '$jobType' for file '$($file._Name)' to queue."
			Add-VaultJob -Name $jobType -Parameters @{ "EntityId" = $file.Id; "EntityClassId" = "FILE" } -Description "Create PDF for file '$($file._Name)' and upload to ERP system" -Priority 110
		}
	}
	catch {
		Write-Error -Message $_.Exception.Message
		ShowMessageBox -Message $_.Exception.Message -Icon Error
	}
 finally {		
		Log -End
	}
}