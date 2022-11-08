#=============================================================================#
# PowerShell script sample for coolOrange powerJobs                           #
# Creates a PDF file and add it to Autodesk Vault as Design Vizualization     #
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#

# JobEntityType = FILE

#region Settings
$hidePDF = $false

# To enable faster opening of released Inventor drawings without downloading and opening their model files set Yes, otherwise No
$openReleasedDrawingsFast = $true
#endregion

$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\ErpService.Create.Pdf-Job.log"
Set-LogFilePath -Path $logPath

Log -Message "Starting job 'Create PDF as attachment' for file '$($file._Name)' ..."

if ( @("idw", "dwg") -notcontains $file._Extension ) {
    Log -Message "Files with extension: '$($file._Extension)' are not supported"
    return
}

ConnectToConfiguredErpServer

$ipjVaultPath = $vault.DocumentService.GetInventorProjectFileLocation()
$workingDirectory = ($vaultConnection.WorkingFoldersManager.GetWorkingFolder("$/")).FullPath
$localIpjFile = (Save-VaultFile -File $ipjVaultPath -DownloadDirectory $workingDirectory)[0]

$fastOpen = $openReleasedDrawingsFast -and $file._ReleasedRevision
$downloadedFiles = Save-VaultFile -File $file._FullPath -ExcludeChildren:$fastOpen -ExcludeLibraryContents:$fastOpen
$file = $downloadedFiles | select -First 1
$openResult = Open-Document -LocalFile $file.LocalPath -Options @{ "Project" = $localIpjFile.LocalPath; FastOpen = $fastOpen } #-Application InventorServer

$localPDFfileLocation = "$workingDirectory\$($file._Name).pdf"
$vaultPDFfileLocation = $file._EntityPath + "/" + (Split-Path -Leaf $localPDFfileLocation)

if ($openResult) {
    if ($openResult.Application.Name -like 'Inventor*') {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF_2D.ini"
    }
    else {
        $configFile = "$($env:POWERJOBS_MODULESDIR)Export\PDF.dwg"
    }
    $exportResult = Export-Document -Format 'PDF' -To $localPDFfileLocation -Options $configFile
    if ($exportResult) {
        $PDFfile = Add-VaultFile -From $localPDFfileLocation -To $vaultPDFfileLocation -FileClassification DesignVisualization -Hidden $hidePDF
        $file = Update-VaultFile -File $file._FullPath -AddAttachments @($PDFfile._FullPath)
        
        if ($Job.ItemNumber) {
            # Make sure you have permissions to modify released items before you use this Job for items with lifecycle change
            Update-VaultItem -Number $Job.ItemNumber -AddAttachments @($PDFfile._FullPath)
        }

        Log -Message "Uploading PDF file $($PDFfile._Name) to ERP system..."
        $d = New-ERPObject -EntityType "Document"
        $d.FileName = $PDFfile._Name
        $d.Number = $file._PartNumber
        $d.Description = $file._Description 
        $uploadPDFToErpResult = Add-ERPMedia -EntitySet "Documents" -Properties $d -ContentType "application/pdf" -File $localPDFfileLocation
    }
    $closeResult = Close-Document
}

if (-not $openResult) {
    throw("Failed to open document $($file.LocalPath)! Reason: $($openResult.Error.Message)")
}
if (-not $exportResult) {
    throw("Failed to export document $($file.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.Error.Message)")
}
if (-not $closeResult) {
    throw("Failed to close document $($file.LocalPath)! Reason: $($closeResult.Error.Message))")
}
if (-not $uploadPDFToErpResult) {
    throw("Failed to upload PDF document to ERP system! Reason: $($Error[0]) (Source: $($Error[0].Exception.Source))")
}
Log -Message "Completed job 'Create PDF as attachment'"