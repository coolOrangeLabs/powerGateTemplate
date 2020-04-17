# BOM dialogue

This dialog is a standard of our coolOrange product powerGate and the [official documentation can be found here](https://www.coolorange.com/wiki/doku.php?id=powergate:bom_window)

## Open

To open the Parts dialog, simply right-click on an item or file in Vault and click "Transfer Parts List":

![create_erpbom](https://user-images.githubusercontent.com/36075173/51521880-33e9db80-1e28-11e9-9c8e-fe1e08621c00.png)

## Article

### Check

`Different` is displayed if the following properties are different:

| Vault Property | {ERP} Property |
| - | - |
| _Description | UserText |

#### Example after pressing "Check".
![check_items](https://user-images.githubusercontent.com/36075173/51521881-33e9db80-1e28-11e9-9d16-913d630970cd.png)

### Transfer

The mapping for automatically generated articles in {ERP} is as follows:

| Vault Property | {ERP} Property | 
| - | - |
| _Number | ItemCode |
| _Descrption | UserText |
| _Units | BaseUnitName |

---

## Parts list

### Check

`Different` is displayed if the following properties are different:

| Vault Property | {ERP} Property |
| - | - |
| Bom_Quantity | Quantity |


### Transfer

The mapping for automatically generated BOMs in {ERP} is as follows:

#### BOM header
| Vault Property | {ERP} Property | 
| - | - |
| _Number | Code |

#### Bom Rows
| Vault Property | {ERP} Property | 
| - | - |
| _Number | Code |
| _Number _(from parent)_ | ParentNumber|
| Bom_Position | LineNum |
| Bom_Quantity | Quantity |
| _Description | LineText |