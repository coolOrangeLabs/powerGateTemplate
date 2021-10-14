param ($Major, $Minor, $Build, $Revision, $Timestamp, $HashCodeFile)

<#
$Major = "22"
$Minor = "1"
$Build = "0"
$Revision = "1"
$timestamp = (Get-Date).ToUniversalTime()
$HashCodeFile = Split-Path $MyInvocation.MyCommand.Path
#>

function Add-CopyRight($fileConent, $version, $buildTime) {
    $copyRight = @"
#=============================================================================#
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
# Verson: {0}                        Buildtime (UTC): {1} #
#=============================================================================#
"@ -f @($version, $buildTime)

    $fileConentWithCopyRight = "$($copyRight)`n`n" + $($fileConent)
    return $fileConentWithCopyRight
}

$currentPath = Split-Path $MyInvocation.MyCommand.Path
Get-ChildItem "$currentPath\Files" -Recurse -Include *.psm1, *.ps1 |
ForEach-Object {
    $fileContent = (Get-Content $_ -Raw)
        
    $version = "$($Major).$($Minor).$($Build).$($Revision)"
    $newContent = Add-CopyRight -fileConent $fileContent -version $version -buildTime $Timestamp
    Set-Content $_ -Value $newContent -Encoding UTF8
    Write-Host "Add copyright to file $($_.Name)"
    
    $hash = Get-FileHash $_
    (Split-Path -Path $hash.Path -Leaf) + "($($hash.Algorithm)): $($hash.Hash)" | Out-File "$HashCodeFile\PSCodeHash.txt" -Append
}