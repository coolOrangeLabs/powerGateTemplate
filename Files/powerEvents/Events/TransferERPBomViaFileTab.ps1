#region Debugging
if((Get-Process -Id $PID).ProcessName -in @('powershell','powershell_ise') -and $host.Name.StartsWith('powerEvents') -eq $false){
	Import-Module powerEvents

	Open-VaultConnection -Server $env:Computername -Vault Vault -User Administrator -Password ""
	$selectedFile = Get-VaultFile -Properties @{ Name = 'FlcRootItem.iam' }

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
	Connect-ERP -Service 'http://localhost:8080/PGS/ErpServices'
}
#endregion

$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange

Remove-CoolOrangeLogging
$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
Set-LogFilePath -Path $logPath


Add-VaultTab -Name 'ERP BOM' -EntityType 'File' -Action {
	param($Script:SelectedItem)

	$erpBomTab_control = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml](Get-Content "$PSScriptRoot\TransferERPBomTab.xaml")))

	$statusMessage_label = $erpBomTab_control.FindName('lblStatusMessage')
	$erpServices = Get-ERPServices -Available
	if (-not $erpServices) {
		$statusMessage_label.Content = "One or more services are not available!"
		$statusMessage_label.Foreground = "Red"
		$erpBomTab_control.IsEnabled = $false
		return $erpBomTab_control
	}

	$unitOfMeasure_comboboxColumn = $erpBomTab_control.FindName('UnitOfMeasureComboboxColumn')
	$unitOfMeasure_comboboxColumn.ItemsSource = @(GetUnitOfMeasuresList)

	$bomStates_combobox = $erpBomTab_control.FindName('BomStates')
	$bomStates_combobox.ItemsSource = @(GetBOMStateList)

	$erpItemTab_GoToBOMButton = $erpBomTab_control.FindName('GoToBomButton')

	$erpBomHeader = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $Script:SelectedItem._PartNumber } -Expand "BomRows"
	if(-not $?) {
		$statusMessage_label.Content = $Error[0]
		$statusMessage_label.Foreground = "Red"
		$erpBomTab_control.IsEnabled = $false
		return $erpBomTab_control
	}

	if(-not $erpBomHeader) {
		$erpItemTab_GoToBOMButton.IsEnabled = $false
	}
	else {
		$erpItemTab_GoToBOMButton.Add_Click({
			param($Sender)

			Start-Process -FilePath $Sender.DataContext.Link
		})
	}
	$erpBomTab_control.DataContext = $erpBomHeader

	$erpItemTab_ShowBomWindowButton = $erpBomTab_control.FindName('ShowBomWindowButton')
	$erpItemTab_ShowBomWindowButton.Add_Click({
		param($Sender, $EventArgs)

		Show-BomWindow -Entity $selectedFile
		[System.Windows.Forms.SendKeys]::SendWait("{F5}")
	})

	return $erpBomTab_control
}