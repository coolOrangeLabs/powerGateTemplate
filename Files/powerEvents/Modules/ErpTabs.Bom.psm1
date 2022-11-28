function ShowBomWindow {
	param(
		$VaultEntity
	)

	Show-BomWindow -Entity $VaultEntity
	[System.Windows.Forms.SendKeys]::SendWait("{F5}")
}

function GoToErpBom {
	param(
		$ErpEntity
	)

	if ($ErpEntity.Link) {
		Start-Process -FilePath $ErpEntity.Link
	}
}
