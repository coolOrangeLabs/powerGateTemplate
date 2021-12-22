[Menu](../README.md) [Home](./home.md)
# Workstation Installation Manual

## Prerequisites

+ Operating system: Windows 7, Windows 8.1, Windows 10
+ .Net Framework 4.7 or higher
+ Autodesk Vault Professional {YEAR}
+ Autodesk Datastandard for Vault {YEAR}
+ Autodesk Inventor Professional {YEAR}
+ Autodesk Datastandard for Inventor {YEAR}
+ [powerGate Client v21](http://download.coolorange.com/)
  + [Installation Guide](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)
+ [powerEvents v22 for Vault 2021](http://download.coolorange.com/)
  + [Installation Guide](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)
+ [powerVault v22 for Vault 2021 ](http://download.coolorange.com/) _(automatically installed with powerEvents)_
  + [Installation Guide](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)

## Installing the customization

### Download

The latest version of the installer _([MSI file](https://docs.microsoft.com/en-us/windows/desktop/msi/windows-installer-portal))_ can be found under the [Releases on Github.](https://github.com/coolOrangeProjects/{REPO_NAME}/releases)

### Install

1. download the installer as described above
1. execute the currently downloaded setup
1. **Important:** Restart Vault / Inventor

PowerShell and XML files are installed under :
+ `C:\ProgramData\Autodesk\Vault {YEAR}\Extensions\Datastandard\Vault.Custom`
+ `C:\ProgramData\Autodesk\Vault {YEAR}\Extensions\Datastandard\CAD.Custom`
+ `C:\ProgramData\coolOrange\powerGate`
+ `C:\ProgramData\coolOrange\powerEvents`

### Updates

To install a newer version, you can run the setup again and it will automatically update the files from the existing installation.

### Uninstall

There are 2 ways to uninstall:
+ Run the same setup and select the "Remove" option in the window.
+ In the _Control Panel -> Programs and Features_ find the software **"powerGate Standard - Client integration for Vault {YEAR}"** and press "Uninstall
