﻿Register-PSFConfigValidation -Name "timespan" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [timespan]$timespan = [PSFramework.Parameter.TimeSpanParameter]$Value }
	catch
	{
		$Result.Message = "Not a Timespan: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $timespan
	
	return $Result
}