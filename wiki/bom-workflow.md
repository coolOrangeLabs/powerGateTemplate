[Menu](../README.md) [Home](./home.md)
# Bill of material workflow

Here we will show you:
1. The requirements of a Vault BOM
1. What information is transferred
1. The powerGate BOM Dialog
1. The [[items workflow|BOM-Workflow-Items]]
1. The [[boms workflow|BOM-Workflow-Boms]]
1. Troubleshooting common problems

### Requirements

The basics:
+ The `structured` BOM must be enabled with Inventor inside the assemblies
+ It is very important the Vault files have been **checked-in with Inventor** in this way its guaranteed that the CAD BOM is fully stored in Vault!
  + Autoloader, Drag&Drop or other migrations can cause troubles!!

### Explanation

For Vault **files**:
+ The Inventor **structured** BOM is transferred to the ERP with consideration of the 'phantom', 'reference', 'purchase' and 'Inseparable' parts
+ AutoCAD BOMs are very limited:
  + Only without XRefs
  + The BOM Properties must be named the same as in Inventor

For Vault **items**:
+ The article BOM is used and transferred to the ERP with consideration of switched off/deactivated rows.
Questions

### powerGate BOM Dialog

This dialog is a standard of our coolOrange product powerGate and the [official documentation can be found here](https://www.coolorange.com/wiki/doku.php?id=powergate:bom_window)

### Troubleshooting
![error](https://user-images.githubusercontent.com/66059728/85734869-a20d8e80-b6fd-11ea-8ecf-15ebad74b8cd.png)

If the BOM Dialog shows just the header with an error message like "check-out the file in Inventor and check it in again" then open the file in Inventor and go to the left. Right-click with the mouse on the iam and select check-out. Make sure all sub-parts are included and check it in again.

![inventor](https://user-images.githubusercontent.com/66059728/85734525-67a3f180-b6fd-11ea-8a96-f1a4a60905fb.png)


