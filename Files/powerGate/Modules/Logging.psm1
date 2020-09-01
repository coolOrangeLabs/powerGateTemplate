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
        $this.LogLevel = [LogLevel]::OFF #TODO: Set this to OFF when not needed anymore, otherwise memory overflow if logFile becomes to big!
        $this.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\cOLog.txt"
        $this.WriteHost = $false
    }
}

$global:loggingSettings = [LoggingSettings]::new()

function Log {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $True, Position = 1)]
        [string]$Message,
        [Parameter(Position = 2)]
        [LogLevel]$LogLevel = [LogLevel]::INFO,
        [switch]$Begin,
        [switch]$End,
        [switch]$MessageBox,
        [switch]$OverrideLog
    )

    Begin {
        if ($LogLevel -gt [LogLevel]::END -and $End) { $LogLevel = [LogLevel]::END }
        elseif ($LogLevel -gt [LogLevel]::BEGIN -and $Begin) { $LogLevel = [LogLevel]::BEGIN }

        $writeLog = [int]$global:loggingSettings.LogLevel -lt [LogLevel]::OFF -and `
            [int]$global:loggingSettings.LogLevel -le $LogLevel

        if (-not $writeLog) { return }

        $OldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $callStack = Get-PSCallStack
        [string[]]$log = @()
    }
    Process {
        try {
            if (-not $writeLog) { return }

            if (($LogLevel -eq [LogLevel]::BEGIN) -or $Begin) { 
                if ($callStack -and $callStack.count -gt 1) {
                    $log += "`n"
                    $log += ">> {0} >>" -f $callStack[1].Command 
                    $log += "Parameters: {0} " -f $callStack[1].Arguments
                }
            }
            if ($Message) {
                $log += "{0}" -f $Message
            }
            if (($LogLevel -eq [LogLevel]::END) -or $End) { 
                if ($callStack -and $callStack.count -gt 1) {
                    $log += "<< {0} <<" -f $callStack[1].Command
                }
            }
        }
        catch {}
    }
    End {
        try {
            if ($writeLog) { 
                $processname = Get-Process -Id $PID | Select-Object -ExpandProperty ProcessName -ErrorAction SilentlyContinue
                if ($processname -iin 'ScriptEditor', 'powershell_ise', 'Code') {
                    $log | FormatLogMessage -LogLevel $LogLevel | Write-Host
                }
                elseif ($global:loggingSettings.WriteHost) {
                    $log | ForEach-Object { Write-Host $_ }
                }

                if ($loggingSettings.LogFile) {
                    if ($loggingSettings.LogFile.Directory.Exists -eq $false) {
                        $loggingSettings.LogFile.Directory.Create()
                    }
                    if ($loggingSettings.LogFile.Directory.Exists) {
                        $log | FormatLogMessage -LogLevel $LogLevel | ForEach-Object { 
                            Out-File -LiteralPath $($loggingSettings.LogFile.FullName) -InputObject $_ -Append:(-not $OverrideLog) -Force -Encoding utf8
                        }
                    }
                }
                $ErrorActionPreference = $OldErrorActionPreference
            }
            if ($MessageBox) { 
                $icon = "Information"
                if ($LogLevel -eq "Error") {
                    $icon = "Error"
                }
                $null = ShowMessageBox -Message $Message -Icon $icon
            }
        }
        catch { }
    }
}

function FormatLogMessage {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $True)]
        [string[]]$Message = @(),
        [LogLevel]$LogLevel = [LogLevel]::INFO
    )
    Process {
        $callStack = Get-PSCallStack
        $spaces = ''
        0..$callStack.Count | ForEach-Object { $spaces += ' ' }
        return "{0} - {1} - {2}{3}" -f [DateTime]::Now.ToString("yyyy/MM/dd HH:mm:ss:ms"), $LogLevel, $spaces, $_
    }
}

function ShowMessageBox {
    param(
        [string]
        $Message,
        [string]
        $Title = "powerGate ERP Integration",
        [System.Windows.Forms.MessageBoxButtons]
        $Button = "OK", # OK, OKCancel, AbortRetryIgnore, YesNoCancel, YesNo, RetryCancel
        [System.Windows.Forms.MessageBoxIcon]
        $Icon = "Information" #icons: Error, Exclamation, Hand, Information, Question, Stop, Warning
    )
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Button, $Icon)
}