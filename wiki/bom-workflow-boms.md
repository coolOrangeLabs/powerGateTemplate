[Menu](../README.md) [Home](./home.md)
# Bill of material workflow: Boms

Here we will show you how to:
1. Verify the BOM
1. Transfer the BOM

## Requirments

Important to read first:
1. The [[basics|BOM-Workflow]]
1. The [[item workflow for the BOM|BOM-Workflow-Items]]

## Verify the BOM

1. Click on an assembly in Vault
1. Click on the tab "ERP BOM"
1. The "ERP: Bill of Material" dialog will appear
1. Hit the "BOM Transfer.." Button
1. The [BOM Dialog](https://www.coolorange.com/wiki/doku.php?id=powergate:bom_window) will show the Inventor structured BOM
1. **Click on the "Boms" tab**
1. Click on "Check" to verify if all BOM headers and BOM rows
1. If BOM rows are on "Error" state, then hover with the mouse on the error icon and fix it manually

For the [[BOMS mapping, see here.|ERP-BOM-Mapping]]

#### Bom rows

| State| When |
| - | - |
| Different | Quantity is different |
| Remove | The ERP row exists only in ERP but was deleted in the Vault BOM |
| Error | No ERP item is linked |

#### Bom headers

| State| When |
| - | - |
| Different | Any sub row has a modification |
| Error | Any sub row has a no ERP item linked |

Solving an `Error`:
1. Hover with the mouse over the error icon
1. Read the tooltip message
1. Fix manually, for instance, set mandatory Vault UDPs


### Transfer the Inventor BOM to ERP

#### Requirments:

+ Check of BOMs was executed
+ No BOMs on `Error`

1. After verifying all BOMs _(above steps)_
1. Click on "Transfer" to fix the states in "New", "Remove" and "Different" automatically
1. If everything is green on `Identical` then the BOM is successfully deployed to ERP
1. You can display the current [[ERP BOM inside Vault|BOM-Display]]

Items with the state:
+ `New` are transferred with the [[items mapping, see here.|ERP-Item-Mapping]]
+ `Different` are updated with the following properties:
  + Description

![image](https://user-images.githubusercontent.com/36075173/84385257-9004f980-abef-11ea-98c8-1119900b1fcb.png)


