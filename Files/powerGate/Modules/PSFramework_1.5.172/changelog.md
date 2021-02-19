﻿# CHANGELOG

## 1.5.172 : 2021-02-09

- Fix: Write-PSFMessageProxy - fails with "Cannot overwrite variable" when writing to host

## 1.5.171 : 2021-02-07

- Upd: LoggingProvider azureloganalytics - added Tags & Data properties to uploaded data

## 1.5.170 : 2021-01-17

- Fix: LoggingProvider console - error initializing configuration
- Fix: LoggingProvider console - fails to properly insert the file into the message

## 1.5.168 : 2021-01-17

- New: Command Add-PSFLoggingProviderRunspace : Adds a runspace to the list of included runspaces on a logging provider instance
- New: Command Remove-PSFLoggingProviderRunspace : Removes a runspace from the list of included runspaces on a logging provider instance
- New: Configuration Validation: guidarray - ensures only legal guids can be added
- New: LoggingProvider: console - enables logging to the console screen
- New: Class PSFramework.Utility.PsfException - adds localization capability to exceptions
- Upd: Logging - Added ability to filter by runspace id
- Upd: Logging - Added level "Error", functionally identical to warning
- Upd: LoggingProvider: eventlog - Messages with the new level "Error" will trigger an error event
- Upd: LoggingProvider: logfile - Added new setting: MutexName - allows handling file access conflict if writing from multiple processes
- Upd: LoggingProvider: logfile - Added new settings: JsonCompress, JsonString and JsonNoComma to better allow just how json logfiles are being created
- Upd: LoggingProvider: splunk - Added new settings: Index, Source and SourceType
- Upd: Set-PSFLoggingProvider - Added `-IncludeRunspaces` and `-ExcludeRunspaces` parameters
- Upd: Set-PSFLoggingProvider - Added `-RequiresInclude` parameter, excluding all messages that match not at least one include rule.
- Upd: Configuration Validation: bool - now accepts a switch parameter type as input
- Upd: Import-PSFConfig - Add `-EnvironmentPrefix` and `-Simple` parameters, allowing import of configuration from environment variables.
- Upd: Configuration - Automatically imports configuration from environment variables on module import.
- Upd: UtilityHost.cs - Added a static property `FriendlyCallstack` returning the current script callstack as a snapshot.
- Fix: LoggingProvider: sql - Fails to write to database due to hardcoded db name on insert (#444)

## 1.4.150 : 2020-09-25

- Fix: Invoke-PSFCallback ignores modulename filter.

## 1.4.149 : 2020-09-02

- Upd: New build tools, to increase convenience when importing into/building from internal source code repositories
- Fix: Set-PSFLoggingProvider - default instances are not created
- Fix: Validation Scriptblock: PSFramework.Validate.FSPath - validates correctly

## 1.4.146 : 2020-08-30

- Major: Redesigned the entire logging system to support multi-instance providers and reduce complexity of building custom logging providers.
- New: Added Tab Expansion Plus Plus code to provide extended tab completion on PS3-4
- New: Argument Transformation Attribute: PsfDynamicTransform - allows dynamic object conversion from PSObject, hashtable, or type from a different library version
- New: Feature PSFramework.Stop-PSFFunction.ShowWarning - Causes calls to Stop-PSFFunction to always show warnings. By default, using "-EnableException $true" will only throw the exception but not show the warning.
- New: Command Get-PSFLoggingProviderInstance : Lists current logging provider instances
- New: Command Export-PSFModuleClass : Publishes a PowerShell class to be available from outside of the module it is defined in.
- New: Command Select-PSFConfig : Select a subset of configuration entries and return them as objects.
- New: Command Test-PSFLanguageMode : Tests, in what language mode a specified scriptblock is in.
- New: Command Import-PSFLoggingProvider : Imports additional logging providers or logging provider configuration from a filesystem path or network url.
- New: Parameter Attribute PsfArgumentCompleter : Extends ArgumentCompleter and replaces the _need_ for Register-PSFArgumentCompleter.
- New: Validation Attribute PsfValidateLanguageMode : Validates the language mode of a scriptblock.
- New: Logging Provider: eventlog - logs to the windows eventlog
- New: Logging Provider: splunk - logs to a splunk SIEM server
- New: Logging Provider: azureloganalytics - logs to Azure Log Analytics
- New: Validation Scriptblock: PSFramework.Validate.FSPath - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.FSPath.File - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.FSPath.FileOrParent - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.FSPath.Folder - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Path - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Path.Container - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Path.Leaf - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Uri.Absolute - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Uri.Absolute.File - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.Uri.Absolute.Https - prebuilt validation scriptblocks for use with PsfValidateScript. Validation messages available with same label.
- New: Validation Scriptblock: PSFramework.Validate.TimeSpan.Positive - prebuilt validation scriptblock for use with PsfValidateScript. Validation messages available with same label.
- New: Configuration Validation: uriabsolute - Ensures the input is an absolute Uri.
- New: Configuration Validation: integer1to9 - Ensures the input is an integer between 1 and 9.
- New: Configuration Setting: PSFramework.Logging.Enabled - allows fully disabling the logging runspace by configuration.
- New: Class PsfScriptBlock - Wraps a scriptblock and provides native support for $_, $this, $args as input. Also supports rehoming your scriptblock to a runspace or the global scope withoutbreaking languagemode.
- New: Class RunspaceBoundValueGeneric - Allows statically maintaining values that may contain specific values per runspace.
- New: Class PSFNumber - Wraps a number into a humanized format while retaining its nature as number
- Upd: Invoke-PSFProtectedCommand - Added `-RetryCondition` parameter to allow custom scriptblocks for retry validation
- Upd: ConvertTo-PSFHashtable - Added `-CaseSensitive` parameter
- Upd: Write-PSFMessage - Support for including level-based prefixes for CI/CD services such as Azure DevOps. (thanks, @splaxi)
- Upd: Write-PSFMessage - New parameter: `-NoNewLine` avoids adding a new line after writing to screen.
- Upd: Write-PSFMessage - New parameter: `-PSCmdlet` will in combination with `-EnableException` and `-ErrorRecord` write the errors in the context of the specified $PSCmdlet.
- Upd: Write-PSFMessage - New parameter: `-Data` allows specifying additional data points for the log
- Upd: Test-PSFPowerShell - now able to execute remotely, testing a target host.
- Upd: New-PSFSupportPackage - added linux & mac support (thanks, @nyanhp)
- Upd: New-PSFSupportPackage - now supports taking console buffer screenshot from ISE
- Upd: Register-PSFLoggingProvider - require FullLanguage language mode on all scriptblock parameters.
- Upd: Register-PSFLoggingProvider - added parameters to allow creation of second generation logging providers.
- Upd: PSFCmdlet - WriteMessage() now also accepts a Hashtable input as Data
- Upd: PSFCmdlet - WriteLocalizedMessage() now also accepts a Hashtable input as Data
- Upd: Logging - Increased log execution interval and added idle detection with extended intervals in non-use to reduce CPU impact.
- Upd: Logging - Disabled autostart of logging runpace in PowerShell Studio Module cacher
- Upd: Logging - Disabled autostart of logging runpace in Azure Functions
- Upd: Logging Provider: logfile - Updated to generation 2 to enable multi-instance capabilities.
- Upd: Logging Provider: logfile - Added new output format: CMTrace
- Upd: Get-PSFConfig - Now accepts from the pipeline
- Upd: Get-PSFConfigValue - Now accepts positional input
- Upd: Set-PSFConfig - Now accepts from the pipeline
- Upd: Set-PSFConfig - Handler scriptblocks can now use $_ instead of $args[0]
- Upd: Unregister-PSFConfig - Added failover on non-windows from UserDefault to FileUserLocal scope
- Upd: Unregister-PSFConfig - Added failover on non-windows from SystemDefault to FileSystem scope
- Upd: Disable-PSFTaskEngineTask - Added Name parameter
- Upd: Enable-PSFTaskEngineTask - Added Name parameter
- Upd: Added debug mode for more visual PSFramework import
- Upd: Added scheduled timer to clean up runspace bound values for runspaces that no longer exist
- Upd: Register-PSFTeppScriptblock - added `-Global` parameter
- Upd: Set-PSFScriptblock - added `-Global` parameter
- Upd: Validation Attribute PsfValidateScript - added `Global = ` named property to execute script in the global context
- Upd: Register-PSFLoggingProvider - flagged as unsafe for JEA
- Upd: Set-PSFTypeAlias - now accepts from the pipeline
- Upd: Stop-PSFFunction - added parameter `-AlwaysWarning`, ensuring it will always show the warning, even when throwing a terminating exception.
- Upd: Logging Provider logfile - added configuration for encoding
- Upd: Logging Provider logfile - added configuration for UTC timestamps
- Upd: Logging Provider logfile - added logrotate capability
- Upd: Logging Provider GELF - converted to v2 provider, enabling multiple instances
- Upd: Configuration Validation timespan - now supports PSFTimespan notation
- Upd: Invoke-PSFProtectedCommand now respects explicitly bound `-WhatIf` and `-Confirm` parameters.
- Upd: Logging Component - Disabled wait time in logging cycle if messages pending, to avoid delays during message floods
- Fix: Register-PSFLoggingProvider - respects `InstallationOptional` setting
- Fix: Install-PSFLoggingProvider - now correctly passes installation parameters as hashtable into the installation scriptblock
- Fix: Set-PSFLoggingProvider - now correctly passes installation parameters as hashtable into the configuration scriptblock
- Fix: ConvertTo-PSFHashtable : The `-Include` parameter functionality was case sensitive (as the sole parameter being so)
- Fix: Missing help for new cmdlets has been fixed and integrated into CI/CD
- Fix: PSFCmdlet - fails with 'Variable was precompiled for performance reasons' in some situations when writing messages.
- Fix: Localization - logging language only honored when specifying string values.
- Fix: Register-PSFLoggingProvider - auto-install fails to notify system of success, failing the registration auto-enable even when it installed correctly.
- Fix: Set-PSFConfig - security fix
- Fix: Set-PSFConfig - security fix
- Fix: Import-PSFConfig - resolved scriptblock handling issues in multi-runspace scenarios
- Fix: Register-PSFConfig - error detecting parameterset in pipeline scenarios
- Fix: Register-PSFConfig - failed to failover for SystemDefault scope on non-Windows
- Fix: Logging Component - Logging Provider Instances would ignore updating filters at runtime
- Fix: Logging Component - Execute proper cleanup when provider / instance get disabled explicitly

## 1.1.59 : 2019-11-02
 - New: Command Get-PSFPath : Returns configured paths.
 - New: Command Set-PSFPath : Configures a path under a specified name.
 - New: Command Compare-PSFArray : Compares two arrays with each other.
 - New: Command Get-PSFCallback : Returns registered callback scripts.
 - New: Command Invoke-PSFCallback : Executes registered callback scripts.
 - New: Command Register-PSFCallback : Registers a callback script.
 - New: Command Unregister-PSFCallback : Removes a registered callback script.
 - New: ATA : TypeTransformationAttribute - transforms input into the target type using powershell type coercion. Use to override language primitive overrides, especially to allow binding switch parameters to bool parameters of commands defined in C#
 - Upd: Invoke-PSFProtectedCommand - now accepts switch parameters on -EnableException
 - Upd: Invoke-PSFProtectedCommand - now accepts ContinueLabel parameter
 - Upd: Invoke-PSFProtectedCommand - now explicitly confirms successful execution
 - Upd: Invoke-PSFProtectedCommand - now supports retry attempts, using `-RetryCount`, `-RetryWait` and `-RetryErrorType` parameters
 - Upd: Export-PSFClixml - add `-PassThru` parameter
 - Upd: Get-PSFTaskEngineCache - collector can no longer be executed in parallel
 - Upd: Logging Provider: logfile - now supports custom time formats in the logfiles
 - Upd: Logging Provider: filesystem - now supports custom time formats in the logfiles
 - Upd: PSFCmdlet - new Invoke() overload supporting scriptblocks as string input
 - Upd: PSFCmdlet - new StopCommand() method to integrate into flowcontrol
 - Upd: PSFCmdlet - new StopLocalizedCommand() method to integrate into flowcontrol
 - Upd: PSFCmdlet - new GetCaller() overload supporting going up a specified number of steps the callstack
 - Upd: PSFCmdlet - new GetCallerInfo() method to obtain optimized/parsed caller information
 - Upd: PSFCmdlet - new InvokeCallback() method to integrate cmdlets into the callback component
 - Fix: Get-PSFTaskEngineCache - collector script no longer bound by runspace affinity.
 - Fix: Import - concurrency issue, parameterclass mappings used to be subject to concurrent access issues.

## 1.0.35 : 2019-08-26
 - Upd: Removed runspace affinity of invoked scriptblocks of taskengine, rather than recreating them
 - Fix: Tab Completion scriptblocks are again aware of $fakeBoundParameter and other automatic variables

## 1.0.33 : 2019-08-11
 - Fix: Build order update fixes unknown attribute error

## 1.0.32 : 2019-08-11
 - New: Validation Attribute: PsfValidateTrustedData - equivalent to ValidateTrustedData, but exists on PS3+ (no effect before 5+)
 - New: Command Import-PSFPowerShellDataFile - wraps around Import-PowerShellDataFile and makes it available on PSv3+
 - Upd: Parameter Class: Computer : Add support for output of Get-ADDomainController
 - Upd: ConvertTo-PSFHashtable : Reimplemented as Cmdlet for better performance
 - Upd: ConvertTo-PSFHashtable : Adding -Inherit parameter, causing the command to pick up missing includes from variables.
 - Upd: Select-PSFObject : Parameter `-Property` now validates for trusted data
 - Upd: Tab Completion: PSFramework-Input-ObjectProperty - will now properly unroll arrays to provide completion for the first value in one.
 - Upd: Register-PSFTeppScriptblock : Changed some internal behavior
 - Fix: Write-PSFMessage fails with error on localized string when specifying an error record
 - Fix: Write-PSFMessage fails with error when specifying $null for format values
 - Fix: Remove-PSFConfig fails to log deleted configuration name
 - Fix: Register-PSFTaskEngineTask fails to reset correctly
 - Fix: PsfValidateSet fails unexpectedly under certain circumstances

## 1.0.19 : 2019-05-21
 - Upd: Import-PSFConfig adding -PassThru parameter.
 - Upd: Write-PSFMessageProxy adding parameters to better support all common redirection scenarios.
 - Upd: FileSystem Logging Provider now supports option to serialize target objects
 - Fix: New-PSFSupportPackage no longer tries to export pssnappins on PowerShell Core
 - Fix: Importing PSFramework within a JEA Endpoint throws exceptions
 - Fix: Closed Memory Leak in Serialization component

## 1.0.12 : 2019-03-20
 - Fix: TaskEngineCache would throw null exception on any access.

## 1.0.11 : 2019-03-20
 - New: Convenience type: `[PSFSize]` will display size numbers in a human friendly way without losing mathematical precision or usefulness as number.
 - Upd: Write-PSFMessage : `-StringValues` parameter has now an alias called `-Format` and can be used together with `-Message` parameter.
 - Upd: Get-PSFTaskEngineCache : Interna rework to utilize expiration of cached data and automatic data refresh.
 - Upd: Set-PSFTaskEngineCache : Added `-Lifetime`, `-Collector` and `-CollectorArgument` parameters to facilitate cache expiration and automatic data refresh.
 - Upd: Test-PSFTaskEngineCache : Interna rework.
 - Upd: Task Engine : Including state information, estimated next execution time and last error.
 - Upd: Test-PSFParameterBinding now supports the `-Mode` parameter, allowing to differentiate between explicitly bound parameters or scriptblocks that will be bound by pipeline input.
 - Upd: PSFCmdlet class for PSFramework implementing Cmdlets now offers a `WriteLocalizedMessage()` method to utilize the localization feature when writing messages.
 - Fix: Write-PSFMessage would not localize correctly

## 1.0.2 : 2019-03-11
 - Upd: ConvertTo-PSFHashtable now supports `-Include` & `-IncludeEmpty` parameter
 - Fix: Broken dynamic parameters for logging providers (#287)

## 1.0.0 : 2019-02-24
Fundamental Change: The configuration system is now extensible in how it processes input.
This unlocks fully supported custom configuration layouts, stored in any preferred notation, hosted by any preferred platform.

Component added: Feature Management
Enables declaring feature flags that can be set both globally as well as controlled or overridden on a per-module basis.

 - New: Command Register-PSFConfigSchema extends the type of input understood as configuration data.
 - New: Command Remove-PSFConfig allows to remove configuration items from memory that have been flagged as deletable.
 - New: Command Select-PSFPropertyValue selects the value of properties based on various conditions.
 - New: Command Register-PSFSessionObjectType registers session objects for use in Session Containers.
 - New: Command New-PSFSessionContainer creates a multi-session object in order to easily be able to pass through sessions to a single computer with multiple protocols.
 - New: Command ConvertFrom-PSFArray flattens object properties for export to csv or other destinations that cannot handle tiered data.
 - New: Command Invoke-PSFProtectedCommand combines should process testing, error handling, messages & logging and flow control into one, neat package.
 - New: Command Get-PSFFeature lists registered features that can be enabled or disabled.
 - New: Command Set-PSFFeature enables or disables features supporting this component.
 - New: Command Test-PSFFeature resolves the enablement status of a feature.
 - New: Command Register-PSFFeature registers a feature within the feature component.
 - New: Optional Feature: PSFramework.InheritEnableException allows inheriting the EnableException variable by commands offering that parameter. This feature is only available on a per-module basis.
 - New: Configuration Schema: 'default'. Old version configuration schema for Import-PSFConfig.
 - New: Configuration Schema: 'MetaJson'. Capable of ingesting complex json files, evaluating and expanding environment variables and loading include files.
 - Upd: Configuration: Removed enforced lowercasing of configuration entries. Configuration as published before had not been case-sensitive, the new version is still not case sensitive.
 - Upd: ConvertTo-PSFHashTable now correctly operates against all dictionaries, including `$PSBoundParameters`
 - Upd: Invoke-PSFCommand will reuse the PSSession in a Session Container.
 - Upd: Import-PSFConfig now has a `-AllowDelete` parameter, enabling the later deletion of imported configuration settings.
 - Upd: Test-PSFShouldProcess now no longer requires specifying the `-PSCmdlet` parameter.
 - Upd: Test-PSFShouldProcess now supports localized strings integration.
 - Upd: Set-PSFConfig now has a `-AllowDelete` parameter, enabling the later deletion of a configuration setting.
 - Upd: Import-PSFConfig now has a `-Schema` parameter, allowing to switch between configuration schemata.
 - Upd: Major push to avoid import static resource conflict when importing in many runspaces in parallel
 - Upd: Wait-PSFMessage will no longer cause lengthy delays when waiting for the logs to flush - now it _knows_ when it's over, rather than guessing with a margin.
 - Fix: Write-PSFMessage strings: Unknown keys will no longer cause an empty message on screen, instead display the missing key.
 - Fix: Configuration - DefaultValue would be overwritten each time a configuration item's `Initialize` property is set (rather than only on the first time it is set to true)
 - Fix: Logs flushing would not reliably trigger in all circumstances

## 0.10.31.179 : 2019-02-07
 - Fix: Broken application of module / tag filters on logging providers (#272)
 - Fix: Write-PSFMessage parameter `-String` would also require a `-StringValues` to be specified
 - Fix: Import-PSFLocalizedString removed validation on parameter `-Language` due to issues when executing during any module import.
 - Fix: Culled logging at the end of a process

## 0.10.31.176 : 2019-01-13
 - New: Configuration validation: Credential. Validates PSCredential objects.
 - New: The most awesome Tab Completion for input properties _ever_ .
 - Upd: Write-PSFMessage supports localized strings through the `-String` and `-StringValues` parameters
 - Upd: Stop-PSFFunction supports localized strings through the `-String` and `-StringValues` parameters
 - Upd: Test-PSFShouldProcess now supports ShouldProcess itself. This should help silence tests on commands reyling on it.
 - Upd: Message component supports localized strings
 - Upd: Logging component logs in separate language than localized messages to screen / userinteraction
 - Upd: Logging - filesystem provider now has a configuration to enable better output information: `psframework.logging.filesystem.modernlog`
 - Upd: Import-PSFLocalizedString now accepts wildcard path patterns that resovle to multiple files.
 - Upd: Adding tab completion for `Register-PSFTeppArgumentCompleter`
 - fix: Missing localization strings - Fix: Missing tab completion for modules that register localized strings

## 0.10.30.165 : 2018-12-01
 - New: Command Join-PSFPath performs multi-segment path joins and path normalization
 - New: Command Remove-PSFAlias deletes global aliases
 - New: Configuration setting to define current language
 - Upd: PsfValidatePattern now supports localized strings using the `ErrorString` property.
 - Fix: Race condition / concurrent access on license content during import with ramping up CPU availability

## 0.10.29.160 : 2018-11-04
 - New: Command ConvertTo-PSFHashtable converts objects into hashtables
 - New: Command Get-PSFPipeline grants access to the current pipeline and all its works.
 - New: Command Get-PSFScriptblock retrieves scriptblocks from a static dictionary
 - New: Command Set-PSFScriptblock stores scriptblocks in a static dictionary
 - New: Command Get-PSFLocalizedString retrieves localied versions of strings
 - New: Command Import-PSFLocalizedString imports localized strings into the strings store
 - New: Logging Provider for gelf / graylog
 - Upd: PsfValidateScript can now consume stored scriptblocks
 - Upd: PsfValidateScript will now understand both $_ and $args[0]
 - Upd: PsfValidateSet now supports localized strings using the `ErrorString` property.
 - Upd: PsfValidateScript now supports localized strings using the `ErrorString` property.
 - Upd: Logging runspace now loads the same copy of PSFramework that spawned it (#238)
 - Fix: PsfValidateSet fails on completion scriptblock with whitespace value
 - Fix: Get-PSFConfig will show bad value in default table. Correct data still stored (#243)

## 0.10.28.144 : 2018-10-28
 - Upd: Module Architecture update
 - Upd: Linked online help for commands (by Andrew Pla)
 - Upd: Configuration - redirected SystemDefault to FileSystem scope on non-Windows systems (#229)
 - Upd: Message/Logging - Error records are now directly associated with their respective message and available as the ErrorRecord property (#230)
 - Fix: Reset-PSFConfig fails with error (#223)
 - Fix: Configuration: Registering empty string will register the wrong value (#224)
 - Fix: Module on UNC Path Fails to Load (#227)
 - Fix: Get-PSFUserChoice handling single options more gracefully (#228)
 - Other: Add formal policy on supported platforms and breaking change policy

## 0.10.27.135 : 2018-10-12
 - Fix: New dynamic content collections' Reset() method doesn't do a thing.

## 0.10.27.134 : 2018-10-12
 - New: Command Get-PSFUserChoice allows prompting the user for a choice
 - New: Configuration Validator: integerarray
 - Upd: Encoding enhanced, now supports UTF8 both with and without BOM
 - Upd: Improved Dynamic Content Objects for concurrent collections
 - Fix: Resolve-PSFPath will fail to resolve "." properly (#209)
 - Fix: Configuration error storing collection values in combination with setting a handler, ending up with nested arrays.

## 0.10.27.128 : 2018-09-14
 - New: Command Wait-PSFMessage waits for logs to be flushed, also offers option to terminate logging runspaces.
 - New: Command ConvertFrom-PSFClixml converts data that was serialized from objects back _into_ that object
 - New: Command ConvertTo-PSFClixml converts objects into clixml data (binary or string, compressed or not)
 - New: Parameter class: EncodingParameter
 - Upd: Register-PSFTaskEngineTask `-Interval` and `-Delay` parameters changed to PSFTimeSpan for greater user convenience
 - Upd: Stop-PSFFunction add `-StepsUpward` parameter, enabling upscope interrupt signals
 - Other: Redesigned module layout and build procedure to compile the module into few files, improving import speed

## 0.9.25.113 : 2018-09-05
 - Fix: Stop-PSFFunction throws null method (#188)

## 0.9.25.112 : 2018-09-04
 - Upd: Select-PSFObject: Supports adding alias properties
 - Upd: Select-PSFObject: Supports adding script property properties
 - Upd: Select-PSFObject: Supports adding script method properties
 - Fix: Stop-PSFFunction fails when called during class constructor (#184)
 - Fix: Stop-PSFFunction fails to interrupt when enabling exceptions but not specifying `-Cmdlet` (#185)

## 0.9.25.107 : 2018-08-18
 - Upd: Select-PSFObject: Rewritten as Cmdlet in C#, in order to better access variables in calling scopes and for better performance.
 - Upd: New-PSFSupportPackage: Add support to selectively pick what gets exported
 - Upd: New-PSFSupportPackage: Add configuration that allows organizations to add information on how to submit support packages.
 - Upd: Set-PSFDynamicContentObject: Add parameters to pre-seed the object with threadsafe collections, such as queues, lists or dictionaries.
 - Fix: Write-PSFMessage will now contain the actual callstack at the time of the writing, rather than when called.
 - Fix: Tab Completion Scriptblocks returning un-enumerated arrays would concatenate their results on result caching
 - Fix: New-PSFSupportPackage will not export errors
 - Fix: Write-HostColor unintentionally adds an extra line between each line.
 - Fix: Select-PSFObject: Erroneously adds module name to the typename when specifying a TypeName from a call within a module.

## 0.9.24.98 : 2018-08-14
 - New: Reset-PSFConfig: Resets configuration items to their intialized value.
 - Upd: Add more comprehensive tests to the configuration system
 - Upd: Add tab completion to various commands
 - Fix: Logging Provider will not properly change settings on configuration change
 - Fix: Import-PSFConfig incorrectly does not support deferred deserialization
 - Fix: Unregister-PSFConfig fails to operate when specifying `-Module` and `-Name` parameters to remvoe registry values
 - Fix: Logging runspace stops when alternative runspace with PSFramework ends

## 0.9.24.91 : 2018-08-08
 - Upd: Export-PSFConfig: Configuration setting set for simple export are no longer marked with a style property, as it is no longer needed and was not simple enough.
 - Upd: Configuration: Made the `Style` property on json configuration files optional for simple style export files.
 - Fix: Register-PSFConfig export of multiple configuration items would only export a single one
 - Fix: Unregister-PSFConfig silently does nothing when selecting a file scope to unregister
 - Fix: Write-PSFMessage overwrites variable $string on host level messages (#164)
 - Fix: Import-PSFConfig will not accept relative filesystem paths

## 0.9.24.85 : 2018-07-31
 - New: Add command Resolve-PSFPath, providing a handy way to resolve input paths in a safe manner.
 - New: Add command Export-PSFClixml, providing clixml export by compressing
 - New: Add command Import-PSFClixml, providing clixml import, both compressed and uncompressed

## 0.9.23.82 : 2018-07-25
 - New: Add command Select-PSFObject, adding the ability to powerfully select stuff.
 - Upd: Stop-PSFFunction now has a `-Cmdlet` parameter, allowing to write exceptions in the calling function's scope.

## 0.9.23.80 : 2018-07-23
 - Fix: Invoke-PSFCommand errors are not handled properly
 - Fix: Write-PSFMessage broke PowerShell v3 compatibility
 - Fix: Write-PSFMessage parameter `-Once` would not display correctly on host levels (#156)

## 0.9.23.77 : 2018-07-10
 - Fix: Write-PSFMessage errors on repeated use of `-Once`

## 0.9.23.76 : 2018-07-09
 - New: PsfValidateSet attribute to handle dynamic validate sets, ties into tab completion system
 - New: Add command Set-PSFTeppResult, allows refreshing tje tab completion cache
 - Upd: Register-PSFTeppScriptblock now supports result caching with timeout
 - Upd: Some documentation updates
 - Upd: Write-PSFMessage now allows empty strings or null values
 - Fix: Failed to handle persisted empty arrays
 - Fix: Failed import in some Linux distributions due to .NET issue in Register-PSFParameterClassMapping & ComputerParameter

## 0.9.22.70 : 2018-06-22
 - Upd: Import-PSFConfig now supports weblinks to raw config files or accepts input as raw json string.
 - Fix: Export-PSFConfig will not export any module cache settings.

## 0.9.22.68 : 2018-06-20
 - New: logfile logging provider, enables dedicated logging to a single file.
 - Upd: Logging providers now have dedicated error stacks to help with debugging
 - Fix: Automatic configuration import will now properly set policy/enforce state.
 - Fix: Set-PSFloggingProvider now updates logging provider configuration settings.
 - Fix: Invoke-PSFCommand fails with an enumeration changed exception when cleaning up sessions
 - Fix: Set-PSFConfig fixed validation of collections

## 0.9.21.62 : 2018-06-12
 - Fix: Invoke-PSFCommand fails with an enumeration changed exception when cleaning up sessions

## 0.9.21.61 : 2018-06-09
 - New: Add command Resolve-PSFDefaultParameterValue, allows inheriting targeted default parameter values from the global scope.
 - New: Add command Invoke-PSFCommand, allows invoking commands with convenient parameterization and automatic integrated session management.
 - Fix: Test-PSFPowerShell rename parameter `-PSEdition` to `-Edition` due to PS6 conflict
 - Fix: Export-PSFConfig fails to accept from pipeline (#134)
 - Fix: Export-PSFConfig ignores `-SkipUnchanged` parameter (#135)

## 0.9.19.55 : 2018-05-27
 - New: Add command Remove-PSFNull, will clean the pipeline from unwanted empty objects.
 - New: Add command Test-PSFShouldProcess, implementing the `-Confirm` and `-WhatIf` parameters for a command. Useful to mock the test and make it more readable.
 - New: Add command Test-PSFPowerShell, allowing simple powershell environment validation and mocking.

## 0.9.18.52 : 2018-05-20
 - New: Add command Import-PSFCmdlet, will register a cmdlet in PowerShell
 - New: Add automatic config import from Json files
 - New: Add selective per module config import from json
 - New: Add simple json export support for improved readability in file
 - Upd: Export-PSFConfig - Added feature to export all marked module settings to dedicated export paths
 - Upd: Import-PSFConfig - Added feature to import from dedicated config paths by modulename
 - Upd: Configuration - Hardened configuration properties enforced by policy against manual changes.
 - Upd: Rewrote Set-PSFConfig as cmdlet for performance reasons
 - Upd: Added config persistence support for Hashtable
 - Upd: Added config persistence support for PSObjects of any kind
 - Upd: New-PSFLicense - Added `-Description` and `-Parent` parameters to support inner licenses that are used within another product.
 - Upd: Write-PSFMessage - Disabled entering debugging breakpoints on debug stream messages when specifying the `-Debug` parameter.
 - Upd: Write-PSFMessage - Added `-Breakpoint` parameter to enter a debugging breakpoint at this location when specifying the `-Debug` parameter.
 - Upd: Messages: Added option `'PSFramework.Message.Style.Breadcrumbs'`, enabling display of the full command call-tree, rather than just the calling function's name in displayed messages
 - Upd: Messages: Added option `'PSFramework.Message.Style.Functionname'`, enabling users to remove the function name from displayed messages.
 - Upd: Messages: Added option `'PSFramework.Message.Style.Timestamp'`, enabling users to remove the timestamp from displayed messages.
 - Upd: Messages: Messages written to debug will also include line number if displayed on screen.
 - Upd: Messages: The in-memory message log now includes the full callstack and the username.

## 0.9.16.44 : 2018-04-22
 - Upd: Add tab completion to Export-PSFConfig.
 - Upd: Import-PSFConfig: Added parameter `-Peek` to allow previewing data.
 - Upd: Import-PSFConfig: Added parameter `-IncludeFilter` and `-ExcludeFilter` to allow filtering on import

## 0.9.16.43 : 2018-04-22
 - New: Add command Export-PSFConfig, will export configuration items to json.
 - New: Add command Import-PSFConfig, will import configuration items from json.
 - Upd: Parameter class `[PSFDateTime]` will now accept integer as seconds relative to now

## 0.9.15.41 : 2018-04-14
 - New: Parameter Attribute: `[PSFValidateScript]`, allowing validating with scripts that offer easy to read messages.
 - New: Parameter Attribute: `[PSFValidatePattern]`, allowing validating with regex patterns that offer easy to read messages.
 - Upd: Configuration from registry order change: All users (enforced) > Per user (enforced) > Per user (default) > All users (default) (#89)
 - Fix: Write-PSFMessage will now properly trigger when called from outside the module with `-Verbose` set
 - Fix: Write-PSFMessage will now properly display color-coded messages in system streams (#91)
 - Fix: Terminating process using exit would hang until Managed Runspace Timeout (#94)

## 0.9.14.37 : 2018-04-02
 - New: Parameter class `[PSFTimeSpan]` allows easy input interpretation of timespan information.
 - New: Parameter class `[PSFDateTime]` allows easy input interpretation of datetime information.

## 0.9.13.35 : 2018-03-31
 - Fix: Register-PSFConfig would fail with unknown parameter `-Depth`

## 0.9.13.34 : 2018-03-30
 - New: Add command Write-PSFMessageProxy (#81)
 - New: Add command Set-PSFTypeAlias (#71)
 - Upd: Rewrite of `Write-PSFMessage` as cmdlet to significantly improve performance
 - Upd: Removing the module or closing the process will now stop all registered runspaces. This is designed to avoid hanging resources.
 - Upd: Configuration: Added `Unchanged` property, in order to allow detection of settings that weren't changed by the user. (#79)
 - Upd: Slight performance improvements on `Stop-PSFFunction`
 - Fix: Fixed critical concept error in Stop-PSFFunction, causing invalid termination in flowcontrol using commands. (#80)

## 0.9.11.25 : 2018-03-11
 - Upd: Ensured PS6 non-Windows capability, making registry calls conditional. Configuration cannot be persisted on non-windows for now
 - Fix: Fixed critical scope error in Stop-PSFFunction, causing invalid termination in flowcontrol using commands.
 - Fix: Fixed tab completion for configuration commands

## 0.9.10.23 : 2018-02-21
 - New: Add command Unregister-PSFConfig (#59)
 - New: Add command New-PSFSupportPackage (#60)
 - Upd: Write-PSFHostColor - new parameters `-NoNewLine` (In line with the same Write-Host parameter) and `-Level` (Allow suppressing messages depending on info message configuration) (#61)
 - Upd: Get-PSFTypeSerializationData - new parameter `-Fragment` allows skipping outer XML shell to add to existing type extension XML. Also cleaned up output. (#53)
 - Upd: Some internal housekeeping that should have no effect outside the module
 - Fix: Set-PSFConfig - Validation of array input would remove all but the first value (#54)

## 0.9.9.20 : 2018-02-18
 - Fix: Failed to restore empty array configurations from registry
 - Fix: Restored single-value arrays from registry as non-array

## 0.9.9.19 : 2018-01-27
 - Upd: Enhanced ComputerParameter parameter class: Supports PSSession and CimSession objects, new property `Type` is available to detect live session objects in order to facilitate reuse. (#46)
 - Fix: Tab Expansion commands parameterization and help have been updated to reflect real use requirements (#14)
 - Fix: Register-PSFTeppArgumentCompleter used to throw exception on PS3/4, interrupting module import in strict mode (#45)

## 0.9.8.17 : 2018-01-19
 - Fix: Fixed bad configuration setting 'PSFramework.Serialization.WorkingDirectory'

## 0.9.8.16 : 2018-01-19
 - New: Added command Register-PSFParameterClassMapping
 - New: Added command Get-PSFTypeSerializationData
 - New: Added command Register-PSFTypeSerializationData
 - New: Added class `[PSFramework.Serialization.SerializationTypeConverter]`, a type serializer that can be used to serialize and deserialize types.
 - Upd: Messages now also include the file and line they were written in

## 0.9.7.14 : 2018-01-17
 - New: Added tests to module
 - New: Added parameter class: ComputerParameter (`[PSFComputer]`)
 - Upd: Stop-PSFRunspace - Upgraded error handling
 - Fix: Get-PSFMessageLevelModifier throw error when output was piped at Remove-PSFMessageLevelModifier
 - Fix: Message logging was completely broken

## 0.9.6.12 : 2018-01-12
 - Fix: Start-PSFRunspace fails on PS3/4 [#22](https://github.com/PowershellFrameworkCollective/psframework/issues/22)