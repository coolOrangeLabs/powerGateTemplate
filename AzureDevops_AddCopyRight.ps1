param ($Major, $Minor, $Build, $Revision, $Timestamp, $HashCodeFile)

<#
$Major = "22"
$Minor = "1"
$Build = "0"
$Revision = "1"
$timestamp = (Get-Date).ToUniversalTime()
$HashCodeFile = Split-Path $MyInvocation.MyCommand.Path
#>

function Add-CopyRight($fileContent, $version, $buildTime) {
    $copyRight = @"
#=============================================================================#
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
# Version: {0}                        Buildtime (UTC): {1} #
#=============================================================================#
"@ -f @($version, $buildTime)

    $fileConentWithCopyRight = "$($fileContent)`n`n" + $($copyRight)
    return $fileConentWithCopyRight
}
function RemoveCopyRight {
    param ($ContentLines)
    $copyRightMatches = $ContentLines | Select-String -Pattern 'Copyright \(c\) coolOrange s\.r\.l\. - All rights reserved\.'
    if ($null -ne $copyRightMatches) {
        Write-Host "remove old copyright"
        foreach ($result in $copyRightMatches) {
            # remove lines including the copy right block and preceeding blank line
            for ($i = $result.LineNumber - 3; $i -lt $result.LineNumber + 2; $i++) {
                if ($i -lt 0 -or $i -ge $ContentLines.Count) {
                    # block is on top -> no blank line preceeding (for legacy script files)
                    continue
                }
            $ContentLines.Set($i,$null)
            }
        }
    }
    return $ContentLines
}
$currentPath = Split-Path $MyInvocation.MyCommand.Path
Get-ChildItem "$currentPath\Files" -Recurse -Include *.psm1, *.ps1 |
ForEach-Object {
    $fileContentLines = (Get-Content $_)
    $fileContentLines = RemoveCopyRight -ContentLines $fileContentLines
    $fileContent = ($fileContentLines -join "`r`n").TrimEnd("`r`n").TrimStart("`r`n")
    $version = "$($Major).$($Minor).$($Build).$($Revision)"
    $newContent = Add-CopyRight -fileContent $fileContent -version $version -buildTime $Timestamp
    Set-Content $_ -Value $newContent -Encoding UTF8
    Write-Host "Add copyright to file $($_.Name)"
    
    $hash = Get-FileHash $_
    (Split-Path -Path $hash.Path -Leaf) + "($($hash.Algorithm)): $($hash.Hash)" | Out-File "$HashCodeFile\PSCodeHash.txt" -Append
}