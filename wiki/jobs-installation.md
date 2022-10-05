[Menu](../README.md) [Home](./home.md)
# Jobs installation

## Prerequisites

+ Operating system: Windows 7, Windows 8.1, Windows 10
+ .Net Framework 4.7 or higher
+ Autodesk Client Vault Professional {YEAR} (includes JobProcessor)
+ Autodesk Inventor (has to be started after installation once to complete registration, otherwise powerJobs is not able to use Inventor)
+ [powerGate v23](http://download.coolorange.com/)
  + [Installation Guide](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)
+ [powerJobs v23](http://download.coolorange.com/)
  + [Installation Guide](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)

## Installing the customization

### Download

The latest version of the installer _([MSI file](https://docs.microsoft.com/en-us/windows/desktop/msi/windows-installer-portal))_ can be found under the [Releases on Github.](https://github.com/coolOrangeProjects/{RepoName}/releases)

### Install

1. download the installer `ErpServices_Jobs_X.X.XXXX_x64.msi` as described above
1. execute the downloaded setup
1. **Important:** Restart Vault / Inventor

PowerShell Jobs and Modules are installed under:
+ `C:\ProgramData\coolOrange\powerJobs\Jobs`
+ `C:\ProgramData\coolOrange\powerJobs\Modules`

### Updates

To install a newer version, you can run the setup again and it will automatically update the files from the existing installation.

### Uninstall

There are 2 ways to uninstall:
+ Run the same setup and select the "Remove" option in the window.
+ In the _Control Panel -> Programs and Features_ find the software **"coolOrange ErpService powerJobs Jobs"** and press "Uninstall
