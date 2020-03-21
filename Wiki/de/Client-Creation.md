# {ERP} Artikel Erstellung

Die Maske sieht folgendermaßen aus:

![Before_Creation_01](https://user-images.githubusercontent.com/43955487/58896281-f3636e00-86f5-11e9-8829-37ff5d96c7f3.PNG)

### Erfolgreiche Erstellung

![Success_Creation_01](https://user-images.githubusercontent.com/43955487/58896282-f3636e00-86f5-11e9-932c-617142f22ab9.PNG)

### Vault Datei aktualisiert (_on Refresh_)

![After_Refresh_Creation_01](https://user-images.githubusercontent.com/43955487/58896283-f3636e00-86f5-11e9-9947-942ea10d6ef6.PNG)

## Vault Artikel

Bei den Artikeln in Vault ist folgendes Mapping:

| Erstellungsmaske | Read-Only | Vault Property | SAP Property | Fixierter Wert |
| - | - | - | - | - |
| Nummer| true | `01 SAP-No.` | `Number` | - |
| Description | false | `02 Short Desc. German` | `Description ` |- |
| Basiseinheit | false  | `13 BOM Unit` | `UnitOfMeasure` | 'PC' |


## Vault Dateien

Bei den Dateien in Vault ist folgendes Mapping:

| Erstellungsmaske | Read-Only | Vault Property | SAP Property | Fixierter Wert |
| - | - | - | - | - |
| Nummer| true | `02 Part Number` | `Number` | - |
| Description | false | `06 Description 1 English` | `Description ` |- |
| Basiseinheit | false  | - | `UnitOfMeasure` | 'PC' |

# {ERP} Artikel Aktualisierung

Die Maske sieht folgendermaßen aus:

![Before_Update](https://user-images.githubusercontent.com/43955487/58896911-51dd1c00-86f7-11e9-8696-63b835d80003.PNG)

### Erfolgreiche Aktualisierung

![Success_Update_01](https://user-images.githubusercontent.com/43955487/58896912-51dd1c00-86f7-11e9-9e86-1545c41a5d7c.PNG)

### Vault Datei aktualisiert (_on Refresh_)

![After_Refresh_Update_01](https://user-images.githubusercontent.com/43955487/58896913-51dd1c00-86f7-11e9-8bb7-04543a443765.PNG)

## Vault Artikel

Bei der Aktualisierung den Artikeln in Vault ist folgendes Mapping:

| Erstellungsmaske | Read-Only | Vault Property | SAP Property | Fixierter Wert |
| - | - | - | - | - |
| Nummer| true | `01 SAP-No.` | `Number` | - |
| Description | false | `02 Short Desc. German` | `Description` |- |
| Basiseinheit | false  | `13 BOM Unit` | `UnitOfMeasure` | 'PC' |

## Vault Dateien

Bei den Dateien in Vault ist folgendes Mapping:

| Erstellungsmaske | Read-Only | Vault Property | SAP Property | Fixierter Wert |
| - | - | - | - | - |
| Nummer| true | `02 Part Number` | `Number` | - |
| Description | false | `06 Description 1 English` | `Description ` |- |
| Basiseinheit | false  | - | `UnitOfMeasure` | 'PC' |


