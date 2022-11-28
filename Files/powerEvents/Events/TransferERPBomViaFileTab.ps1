#region TO BE REMOVED
if((Get-Process -Id $PID).ProcessName -eq 'powershell' -and $host.Name.StartsWith('powerEvents')){
	return
}
if([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'MTA' -and (Get-Process -Id $PID).ProcessName -ne 'powershell'){
	Start-Process powershell.exe -ArgumentList "-STA",$MyInvocation.InvocationName -WindowStyle hidden
	return
}

Import-Module powerEvents
Open-VaultConnection -Server $env:Computername -Vault Vault -User Administrator -Password ""
$selectedFile = Get-VaultFile -Properties @{Name = 'FlcRootItem.iam'}

function Add-VaultTab($name, $EntityType, $Action){
	Add-Type -AssemblyName PresentationFramework

	$xamlReader = New-Object System.Xml.XmlNodeReader ([xml]@'
	<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
		<Window.Resources>
			<Style TargetType="{x:Type Window}">
				<Setter Property="FontFamily" Value="Segoe UI" />
				<Setter Property="Background" Value="#FFFDFDFD" />
			</Style>
		</Window.Resources>
	</Window>
'@)
	$debugERPTab_window = [Windows.Markup.XamlReader]::Load($xamlReader)
	$debugERPTab_window.Title = "powerGate Debug Window for Tab: $name"
	$debugERPTab_window.AddChild($action.InvokeReturnAsIs($selectedFile))
	$debugERPTab_window.ShowDialog()
}


Import-Module powergate
Connect-ERP -Service 'http://thomas-rossi:8080/PGS/ErpServices'
#endregion

$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange

Remove-CoolOrangeLogging
$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
Set-LogFilePath -Path $logPath


Add-VaultTab -Name 'ERP BOM' -EntityType 'File' -Action {
	param($selectedFile)

	$Script:erpBomTab_control = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml](Get-Content "$PSScriptRoot\ERPBOM_Tab.xaml")))

	#region Initialize viewmodel
	$bomTabContext = New-Object -Type PsObject -Property @{
		ErpEntity = $null
		VaultEntity = $selectedFile

		Lists = @{
			BomStatesList = @(GetBOMStateList)
			UomList = @(GetUnitOfMeasuresList)
		}
	}
	#endregion Initialize viewmodel


	#region Initialize UI Components
	$erpItemTab_ShowBomWindowButton = $Script:erpBomTab_control.FindName("ShowBomWindowButton")
	$erpItemTab_ShowBomWindowButton.Add_Click({
		param($Sender, $EventArgs)

		ShowBomWindow -VaultEntity $Sender.DataContext.VaultEntity
	})

	$erpItemTab_GoToBomButton = $Script:erpBomTab_control.FindName("GoToBomButton")
	$erpItemTab_GoToBomButton.Add_Click({
		param($Sender)

		GoToErpBom -ErpEntity $Sender.DataContext.ErpEntity
	})
	#endregion Initialize UI Components

	$erpServices = Get-ERPServices -Available
	if (-not $erpServices) {
		$Script:erpBomTab_control.FindName("lblStatusMessage").Content = "One or more services are not available!"
		$Script:erpBomTab_control.FindName("lblStatusMessage").Foreground = "Red"
		$Script:erpBomTab_control.IsEnabled = $false
		return $Script:erpBomTab_control
	}

	$number = GetEntityNumber -entity $selectedFile
	$erpBomHeader = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows"
	if(-not $?) {
		$Script:erpBomTab_control.FindName("lblStatusMessage").Content = $Error[0]
		$Script:erpBomTab_control.FindName("lblStatusMessage").Foreground = "Red"
		$Script:erpBomTab_control.IsEnabled = $false
		return $Script:erpBomTab_control
	}

	if(-not $erpBomHeader) {
		$Script:erpBomTab_control.FindName("GoToBomButton").IsEnabled = $false
	}
	else {
		$bomTabContext.ErpEntity = $erpBomHeader
		$Script:erpBomTab_control.FindName("GoToBomButton").IsEnabled = $true
	}

	$Script:erpBomTab_control.DataContext = $bomTabContext
	return $Script:erpBomTab_control
}
