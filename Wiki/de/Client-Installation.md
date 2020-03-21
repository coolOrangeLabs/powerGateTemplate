# Client Installation für Vault und Inventor

## Vorraussetzungen

+ Betriebssystem: Windows 7, Windows 8.1, Windows 10
+ .Net Framework 4.7 oder höher
+ Autodesk Vault Professional {Year}
+ Autodesk Datastandard for Vault {Year}
+ Autodesk Inventor Professional {Year}
+ Autodesk Datastandard for Inventor {Year}
+ [powerGate v20](http://download.coolorange.com/)
  + [Installationsanleitung](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)
+ [powerVault v20 for Vault 2019](http://download.coolorange.com/)
  + [Installationsanleitung](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)

## Anpassungen installieren

### Download

Die akutellste Version des Installers _([MSI Datei](https://docs.microsoft.com/en-us/windows/desktop/msi/windows-installer-portal))_ befindet sich unter den [Releases auf Github.](https://github.com/coolOrangeProjects/{RepoName}/releases)

### Installieren

1. Den Installer wie oben beschrieben herunterladen
1. Das gerade heruntergeladene Setup auszuführen
1. **Wichtig:** Vault / Inventor neustarten

Installiert werden PowerShell und XML Dateien unter:
+ `C:\ProgramData\Autodesk\Vault 2019\Extensions\Datastandard\Vault.Custom`
+ `C:\ProgramData\Autodesk\Vault 2019\Extensions\Datastandard\Powergate`(modules) 
+ `C:\ProgramData\Autodesk\Vault 2019\Extensions\Datastandard\CAD.Custom`


### Updates

Um eine neuere Version zu installieren, kann das Setup wieder ausgeführt werden und dabei werden automatisch die Dateien von der existierenden Installation aktualisiert.

### Deinstallieren

Zum Deinstallieren gibt es 2 Möglichkeiten:
+ Das gleiche Setup auszuführen und im Fenster die Option "Entfernen" auswählen
+ In die _Systemsteuerung -> Programs and Features_ die Software **"powerGate Standard - Client integration for Vault 2019"** finden und "Deinstallieren" drücken