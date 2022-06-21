<#
This module provides functionality to create syncronize and update revision table jobs for Autodesk Vault. It was tested with powerJobs 17.0.31 and is provided "as is".
#>
function Get-JobParam($Key,$Value) {
    Write-Host ">> $($MyInvocation.MyCommand.Name) >>"
    Write-Host "Key = $($Key) Value = $($Value)"
	$jobParam = New-Object Autodesk.Connectivity.WebServices.JobParam
	$jobParam.Name = $Key
	$jobParam.Val = $Value
	return $jobParam
}
function QueuePropSyncJob {
<#
.SYNOPSIS
This function creates an Autodesk.Vault.SyncProperties job for the passed in file.
.DESCRIPTION
This function creates an Autodesk synchronize job. It can also queue a DWF job. The latest file version is used per default, as you can only update the tip version.
.PARAMETER File
This needs to be a powerVault file object or a Autodesk.Connectivity.WebServices.File object
.PARAMETER Priority
This is the priority, the generated job will have in the job queue. Lower values mean higher priority
.PARAMETER QueueDWFJob
If this switch is set an Autodesk DWF job will be generated as well for the passed in file.
.REMARKS
If the QueueDWFJob switch is set when calling QueuePropSyncJob AND QueueUpdateRevTableJob and they are called in consecution you might get an error because this will create a duplicate job.
You might need to turn off the job creation by Vault to avoid duplicate jobs and other complications.
.EXAMPLE
$vdfFile = QueuePropSyncJob -File $file
.EXAMPLE
$vdfFile = QueuePropSyncJob -File $file -QueueDWFJob
#>
param(
$File,
[int]$Priority = 10,
[switch]$QueueDWFJob
)
    Write-Host ">> $($MyInvocation.MyCommand.Name) >>"
	[Autodesk.Connectivity.WebServices.JobParam[]] $params = @()
	$fileId = (Get-VaultFile -FileId $file.MasterId).Id
	
    

    $paramFileId = Get-JobParam -Key "FileVersionId" -Value "$fileId"
    #EntityId and EntityClassId are actually not needed by the job, but are passed in anyway just in case this will be changed in the future
	$paramEntityId = Get-JobParam "EntityId" "$fileId"
	$paramEntityClassId = Get-JobParam "EntityClassId" "FILE"

	$params += $paramFileId
    $params += $paramEntityId
    $params += $paramEntityClassId

    if($QueueDWFJob.ToBool()) {
        $params += Get-JobParam -Key "QueueCreateDwfJobOnCompletion" -Value "True"
    }

	return $VaultConnection.WebServiceManager.JobService.AddJob("Autodesk.Vault.SyncProperties", "Synchronize properties for file $($file._Name)", $params, $priority)
}
function QueueUpdateRevTableJob {
<#
.SYNOPSIS
This function creates an Autodesk.Vault.UpdateRevisionBlock.*** job for the passed in file. The latest file version is used per default, as you can only update the tip version.
.DESCRIPTION
This function creates an Autodesk update revision block job. It can also queue a DWF job. The latest file version is used per default, as you can only update the tip version.
.PARAMETER File
This needs to be a powerVault file object or a Autodesk.Connectivity.WebServices.File object
.PARAMETER Priority
This is the priority, the generated job will have in the job queue. Lower values mean higher priority
.PARAMETER QueueDWFJob
If this switch is set an Autodesk DWF job will be generated as well for the passed in file.
.REMARKS
If the QueueDWFJob switch is set when calling QueuePropSyncJob AND QueueUpdateRevTableJob and they are called in consecution you might get an error because this will create a duplicate job.
When you are manually queueing the update revision table job you might need to turn off the creation by Vault to avoid duplicate jobs.
.EXAMPLE
$vdfFile = QueueUpdateRevTableJob -File $file
.EXAMPLE
$vdfFile = QueueUpdateRevTableJob -File $file -QueueDWFJob
#>
param(
$File,
[int]$Priority = 10,
[switch]$QueueDWFJob
)
    Write-Host ">> $($MyInvocation.MyCommand.Name) >>"
    switch($file._Extension) {
        "dwg" { $jobname = "Autodesk.Vault.UpdateRevisionBlock.dwg"; break; }
        "idw" { $jobname = "Autodesk.Vault.UpdateRevisionBlock.idw"; break; }
        default { Write-Host "Files of type $($File._Extension) are not supported. "}
    }
	[Autodesk.Connectivity.WebServices.JobParam[]] $params = @()
	$fileId = (Get-VaultFile -FileId $file.MasterId).Id

    $paramFileId = Get-JobParam -Key "FileVersionId" -Value "$fileId"
    #EntityId and EntityClassId are actually not needed by the job, but are passed in anyway just in case this will be changed in the future
	$paramEntityId = Get-JobParam "EntityId" "$fileId"
	$paramEntityClassId = Get-JobParam "EntityClassId" "FILE"

	$params += $paramFileId
    $params += $paramEntityId
    $params += $paramEntityClassId

    if($QueueDWFJob.ToBool()) {
        $params += Get-JobParam -Key "UpdateViewOption" -Value "True"
    }

	return $VaultConnection.WebServiceManager.JobService.AddJob($jobname, "Update revision table for file $($file._Name)", $params, $priority)
}
