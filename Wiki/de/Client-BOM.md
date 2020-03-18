# BOM Dialog

Dieser Dialog ist ein Standard von unseren coolOrange Produkt powerGate und die [offizielle Dokumentation befindet sich hier.](https://www.coolorange.com/wiki/doku.php?id=powergate:bom_window)

## Öffnen

Um den Stückliten Dialog zu Öffnen, einfach `Rechts-klick` auf ein Artikel oder Datei in Vault und "Stückliste Übertragen" anklicken:

![create_erpbom](https://user-images.githubusercontent.com/36075173/51521880-33e9db80-1e28-11e9-9c8e-fe1e08621c00.png)

## Artikel

### Prüfen

`Different` wird angezeigt wenn folgende Properties unterschiedlich sind:

| Vault Property | SAP Property |
| - | - |
| _Description | UserText |

#### Beispiel nach dem Drücken von "Prüfen"
![check_items](https://user-images.githubusercontent.com/36075173/51521881-33e9db80-1e28-11e9-9d16-913d630970cd.png)

### Übermittelen

Das Mapping für automatisch erzeugte Artikel in SAP sieht wie folgt aus:

| Vault Property | SAP Property | 
| - | - |
| _Number | ItemCode |
| _Descrption | UserText |
| _Units | BaseUnitName |

---

## Stückliste

### Prüfen

`Different` wird angezeigt wenn folgende Properties unterschiedlich sind:

| Vault Property | SAP Property |
| - | - |
| Bom_Quantity | Quantity |


### Übermittelen

Das Mapping für automatisch erzeugte Stücklisten in SAP sieht wie folgt aus:

#### Stücklisten Kopf
| Vault Property | SAP Property | 
| - | - |
| _Number | Code  |

#### Stücklisten Zeile
| Vault Property | SAP Property | 
| - | - |
| _Number | Code  |
| _Number _(vom Parent)_ | Father  |
| Bom_Position | LineNum |
| Bom_Position | U_POSNR |
| Bom_Quantity | Quantity |
| _Description | LineText |