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

$script:supportedDwfExtensions = @("iam", "idw", "dwg", "ipn", "ipt")

Register-VaultEvent -EventName UpdateFileStates_Restrictions -Action 'RestrictFileRelease'
function RestrictFileRelease($files) {
	foreach ($file in $files) {
		if ($file._NewState -like "*release*") {
			$material = Get-ERPObject -EntitySet "Materials" -Key @{"Number" = $file._PartNumber }
			if ($null -eq $material) {
				Add-VaultRestriction -EntityName ($file._Name) -Message "An item with the number '$($file._PartNumber)' does not exist in the ERP system."
			}
		}
	}
}

Register-VaultEvent -EventName UpdateFileStates_Post -Action 'AddPdfJob'
function AddPdfJob($files, $successful) {
    if(-not $successful) {
		return 
	}
    $releasedFiles = @($files | Where-Object { $supportedDwfExtensions -contains $_._Extension -and $_._ReleasedRevision -eq $true })
    foreach($file in $releasedFiles) {
        $jobType = "ErpService.Create.PDF"
        Write-Host "Adding job '$jobType' for released file '$($file._Name)' to queue."
        Add-VaultJob -Name $jobType -Parameters @{ "EntityId"=$file.Id; "EntityClassId"="FILE" } -Description "Create PDF for file '$($file._Name)' and upload to ERP system"
   }
}