function InitBomTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity
	$getErpBomHeaderResult = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows"

	if(-not $getErpBomHeaderResult) {
		$goToEnabled = $false
	}
	else {
		$goToEnabled = $true
	}
	$dswindow.FindName("DataGrid").DataContext = $getErpBomHeaderResult
	$dswindow.FindName("GoToBomButton").IsEnabled = $goToEnabled
}

function GoToErpBom {
	$bom = $dswindow.FindName("DataGrid").DataContext
	if ($bom.Link) {
		Start-Process -FilePath $bom.Link
	}
}
