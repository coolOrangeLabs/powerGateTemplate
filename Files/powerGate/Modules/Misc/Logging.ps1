enum LogLevel {
    ALL;
    LOOP2;
    LOOP;
    DEBUG;
    END;
    BEGIN;
    INFO;
    ERROR;
    OFF
}
class LoggingSettings {
    [LogLevel] $LogLevel 
    [bool] $WriteHost
    [System.IO.FileInfo]$LogFile

    LoggingSettings() {
        $this.LogLevel = [LogLevel]::DEBUG
        $this.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Custom\cOLog.txt"
        $this.WriteHost = $false
    }
}

$global:loggingSettings = [LoggingSettings]::new()

function Log {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$True, Position=1)]
        [string]$Message = "`r`n",
        [Parameter(Position=2)]
        [LogLevel]$LogLevel = [LogLevel]::INFO,
        [switch]$Begin,
        [switch]$End,
        [switch]$MessageBox,
        [switch]$OverrideLog
    )

    Begin {
        if($LogLevel -gt [LogLevel]::END -and $End) { $LogLevel = [LogLevel]::END }
        elseif($LogLevel -gt [LogLevel]::BEGIN -and $Begin) { $LogLevel = [LogLevel]::BEGIN }

        $writeLog = [int]$global:loggingSettings.LogLevel -lt [LogLevel]::OFF -and `
                    [int]$global:loggingSettings.LogLevel -le $LogLevel

        if(-not $writeLog) { return }

        $OldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $callStack = Get-PSCallStack
        [string[]]$log = @()
    }
    Process {
        try {
            if(-not $writeLog) { return }

            if(($LogLevel -eq [LogLevel]::BEGIN) -or $Begin) { 
                if($callStack -and $callStack.count -gt 1) {
                    $log += ">> {0} >>" -f $callStack[1].Command 
                    $log += "Parameters: {0} " -f $callStack[1].Arguments
                }
            }
            if($Message) {
                $log += "{0}" -f $Message
            }
            if(($LogLevel -eq [LogLevel]::END) -or $End) { 
                if($callStack -and $callStack.count -gt 1) {
                    $log += "<< {0} <<" -f $callStack[1].Command 
                }
            }
        }
        catch {}
    }
    End {
        try {
            $processname = Get-Process -Id $PID | Select-Object -ExpandProperty ProcessName -ErrorAction SilentlyContinue
            if($processname -iin 'ScriptEditor', 'powershell_ise', 'Code') {
                $log | Format-LogMessage | Write-Host
            }
            elseif($global:loggingSettings.WriteHost) {
                $log | ForEach-Object { Write-Host -InputObject $_ }
            }

            if($loggingSettings.LogFile) {
                if($loggingSettings.LogFile.Directory.Exists -eq $false) {
                    $loggingSettings.LogFile.Directory.Create()
                }
                if($loggingSettings.LogFile.Directory.Exists) {
                    $log | Format-LogMessage | ForEach-Object { 
                        Out-File -LiteralPath $($loggingSettings.LogFile.FullName) -InputObject $_ -Append:(-not $OverrideLog) -Force -Encoding utf8
                    }
                }
            }

            if($MessageBox) { $null = New-MessageBox -Text $Message -Button Ok}
        
            $ErrorActionPreference = $OldErrorActionPreference
        }
        catch { }
    }
}
function Format-LogMessage {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$True)]
        [string[]]$Message = @()
    )
    Process {
        $callStack = Get-PSCallStack
        $spaces = ''
        0..$callStack.Count | ForEach-Object { $spaces += ' ' }
        return "{0} - {1}{2}" -f [DateTime]::Now.ToString("yyyy/MM/dd hh:mm:ss:ms"), $spaces, $_
    }
}

function New-MessageBox
{
	param
	(
		[string]
		$Text,

		[string]
		$Caption,

		[System.Windows.MessageBoxButton]
		$Button,

		[System.Windows.MessageBoxImage]
		$Icon
	)
	return [System.Windows.MessageBox]::Show($Text, $Caption, $Button, $Icon)
}