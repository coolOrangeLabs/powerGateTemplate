[Menu](../README.md) [Home](./home.md)
## Technology: C# SDK

_If we get a .Net DLL for the ERP API, then we have prepared an interface of what we required._

Follow these steps to create your implementation of the interface:
1. Create a new solution in Visual Studio, the new project should have the following settings:
   1. Output Type: `Class Library`
   1. Target `.Net framework: 4.5`
   1. Platform Target: `Any CPU`
1. Reference the assembly powerGateServer.SDK ([download](https://github.com/coolOrangeLabs/powerGateTemplate/files/4831522/powerGateServer.SDK.zip))
1. Copy the interface and required types:
   1. [Interfaces](https://github.com/coolOrangeLabs/powerGateTemplate/tree/master/Files/powerGatePlugin/ErpServices/ErpManager/Interfaces)
   1. [Metadata](https://github.com/coolOrangeLabs/powerGateTemplate/tree/master/Files/powerGatePlugin/ErpServices/Metadata)
1. Create your implementation of `IErpManager`
1. **Very important:** Changes to the interface should be avoided, but if necessary, propose a new interface to coolOrange in order to approve it.
