### Vault Dateien

Die Eingabe im Textfeld ist für die Suche im Property `Sap_No`:

![Suche_Filter_SapNo](https://user-images.githubusercontent.com/43955487/58897067-bf894800-86f7-11e9-887e-81d65877940b.PNG)

Bei Auswahl und Drücken der Schaltfläche `Verknüpfen...`:

![Linked_UpdatedProperties_VaultEntity](https://user-images.githubusercontent.com/43955487/58897068-bf894800-86f7-11e9-8ee6-99bf1ecd74d5.PNG)

Die Verknüpfung der Eigenschaften ist wie folgt:

| Suchen Spalte| Gezielte Vault Eigenscaft| SAP Property | 
| - | - | - |
| Nummer | `02 Part Number` | `Number` |
| Description  | `06 Description 1 English` | `Description ` |
| Basiseinheit | - | `UnitOfMeasure` |


### Vault Artikeln

Die gleiche Logik von Dateien wird für Artikeln verwendet. Die Verknüpfung der Eigenschaften ist wie folgt:

| Suchen Spalte| Gezielte Vault Eigenscaft| SAP Property | 
| - | - | - |
| Nummer | `01 SAP-No.` | `Number` |
| Description | `02 Short Desc. German` | `Description ` |
| Basiseinheit | `13 BOM Unit` | `UnitOfMeasure` |