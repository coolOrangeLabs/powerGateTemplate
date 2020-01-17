function InitializeWindow {
	#begin rules applying commonly
	$dsWindow.Title = SetWindowTitle		
	InitializeCategory
	InitializeNumSchm
	InitializeBreadCrumb
	InitializeFileNameValidation
	#end rules applying commonly
	$mWindowName = $dsWindow.Name
	switch ($mWindowName) {
		"InventorWindow" {
			#rules applying for Inventor
		}
		"AutoCADWindow" {
			#rules applying for AutoCAD
		}
	}
	$global:expandBreadCrumb = $true
	InitializeWindow_powerGate	
}