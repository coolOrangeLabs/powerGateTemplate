# JobEntityType = ITEM

#region Settings
$hidePDF = $false

# To enable faster opening of released Inventor drawings without downloading and opening their model files set Yes, otherwise No
$openReleasedDrawingsFast = $true
#endregion

$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\ErpService.Create.Pdf-Job.log"
Set-LogFilePath -Path $logPath

Write-Host "Starting job 'Create PDF as attachment' for item '$($item._Name)' ..."

ConnectToConfiguredErpServer

$attachedDrawings = Get-VaultItemAssociations -Number $item._Number
foreach ($drawing in $attachedDrawings) {
    $localPDFfileLocation = "$workingDirectory\$($drawing._Name).pdf"
    $vaultPDFfileLocation = $drawing._EntityPath + "/" + (Split-Path -Leaf $localPDFfileLocation)

    Log -Message "Create PDF as attachment for file '$($drawing._Name)' ..."

    if ( @("idw", "dwg") -notcontains $drawing._Extension ) {
        Log -Message "Files with extension: '$($drawing._Extension)' are not supported"
        continue
    }

    $drawing = Get-VaultFile -File $drawing._FullPath -DownloadPath $workingDirectory
    $openResult = Open-Document -LocalFile $drawing.LocalPath
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
            $item = Update-VaultItem -Number $item._Number -AddAttachments @($PDFfile.'Full Path')

            # Log -Message "Uploading PDF file $($PDFfile._Name) to ERP system..."
            # $d = New-ERPObject -EntityType "Document"
            # $d.FileName = $PDFfile._Name
            # $d.Number = $drawing._PartNumber
            # $d.Description = $drawing._Description
            # $uploadPDFToErpResult = Add-ERPMedia -EntitySet "Documents" -Properties $d -ContentType "application/pdf" -File $localPDFfileLocation
        }
        $closeResult = Close-Document
    }

    if (-not $openResult) {
        throw("Failed to open document $($drawing.LocalPath)! Reason: $($openResult.Error.Message)")
    }
    if (-not $exportResult) {
        throw("Failed to export document $($drawing.LocalPath) to $localPDFfileLocation! Reason: $($exportResult.Error.Message)")
    }
    if (-not $closeResult) {
        throw("Failed to close document $($drawing.LocalPath)! Reason: $($closeResult.Error.Message))")
    }
    #if (-not $uploadPDFToErpResult) {
    #    throw("Failed to upload PDF document to ERP system! Reason: $($Error[0]) (Source: $($Error[0].Exception.Source))")
    #}
}
Log -Message "Completed job Create PDF as attachment"