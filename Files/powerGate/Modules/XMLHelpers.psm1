function checkEncoding {
    param (
        [string]$path,
        [string]$encoding
    )
    try {
        $xml = [xml](Get-Content -path $path)
    }
    catch {
        throw "checkEncoding: File is not a valid xml file"
    }
    $xmlDefinition = $xml.xml
    if (-not $xmlDefinition) {
        $ret = $false
    }
    else {
        $encoding = $encoding.toUpper()
        $xmlDefinition = $xmlDefinition.toUpper()
        [bool]$ret = ($xmlDefinition -match ('"'+$encoding+'"'))
    }
    return $ret
}