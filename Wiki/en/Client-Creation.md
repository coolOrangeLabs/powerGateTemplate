# {ERP} Article Creation

If an item is not available in the ERP, the _Number_ and _Decsription_ variables of the selected Vault file are automatically filled into the fields of the _ERP Item_ tab (see below the mapping). The creation mask looks like this:

![create_items](https://user-images.githubusercontent.com/36075173/51395009-022cf800-1b3c-11e9-8ba7-fc7dec10b8a7.png)

### Successful creation

![created_file](https://user-images.githubusercontent.com/36075173/51520930-54646680-1e25-11e9-9ee6-da28c7bf6ee4.png)

# {ERP} Article Update

If an element is already available in the ERP, you can change the variables in the fields of the `ERP Item` tab:

_Add update photo_

### Successful Update


# Vault Article Mapping

## Items

For the items in Vault there is the following mapping:

| Creation mask | Read-Only | Vault Property | {ERP} Property |
| - | - | - | - |
| Number | true | `_Number` | `ItemCode` |
| Description | false | `_Description` | ` User_Text` |
| Unit of Measure | false | `_Description` | `BaseUnitName` |


## Files

For the files in Vault there is the following mapping:

| Creation mask | Read-Only | Vault Property | {ERP} Property |
| - | - | - | - |
| Number | true | `_Number` | `ItemCode` |
| Description | false | `_Description` | ` User_Text` |
| Unit of Measure | true | `_Units` | `BaseUnitName` |

_**Important Remarks**_: 
+ For both creation and update, the manually inserted values in the mask have priority to the Vault values of the mapped UDPs. That is, the `ERP Item` is fed initially with the Vault existing values, but the finally transferred values will be the user modified ones.

+ For both creation and update (only from `ERP Item`, not BOM Window), the transferred properties to the ERP System will be also updated in Vault.  