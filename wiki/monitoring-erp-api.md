[Menu](../README.md) [Home](./home.md)
## Monitoring

We want to guarantee stable software and a fast error notification if some ERP service or functionality is suddenly not available for our customers:

+ We develop some basic tests for the ERP API:
  + _Create a new ERP Item with default values_
  + _Search ERP items by the number, description, or similar properties_
  + _Update an existing ERP item_
  + _Other tests depending on the ERP System and complexity_
+ These tests are **executed daily** at 6 am on the test environment
  + This ensures that the responsible people are notified a maximum of 24 hours later about a broken ERP API service
+ Important information: These tests are creating a lot of new items in the database every day

## Emails

When all tests were **successful** then:
  + An email is sent out to coolOrange, the customer IT and the ERP team
    + Attached is a performance report of the ERP API calls in order to understand when some operations slowed down

![image](https://user-images.githubusercontent.com/36075173/102881106-a6b4c480-444c-11eb-81b0-4d4d9e413f8f.png)


When at least one test has **failed** then:
  + An email is sent out to coolOrange, the customer IT and the ERP team
    + Attached the test result as a `TRX` file

![image](https://user-images.githubusercontent.com/36075173/102881115-a87e8800-444c-11eb-96c4-f4df43f655d3.png)

**What should I do when an ERP test failed?**
1. Understand what test failed: _Only the creation of the ERP Item or every test because the system is down?_
   1. Open with Visual studio the TRX file or
   1. Open Notepad, since the content of the TRX file its in XML you can search for the string `outcome="Failed"` in order to understand what went wrong 
1. Stop with testing in the Vault or Inventor and since it can lead to unexpected behavior
1. Depending on the failed test:
   1. If all tests are failing or a test fails which should definitely work: 
      1. Ask first the intern IT what happened in the last 24 hours to the test system, maybe an Upgrade or Import
      1. If the IT has no answer then ask the ERP Team what happened in the last 24 hours to the test system, maybe the delivered a new API with breaking changes
   1. If a test fails which expects a specific ERP Item: **Check yourself** in the ERP Client if this specific item still exists or was recently changed by a user
   1. If tests are failing and neither IT nor the ERP Team can solve it contact coolOrange and they will dig deeper.


### Releases

On every release, the performance report is attached in the `Assets` for downloading and comparing over time the execution times.

### After Go-Live

The configured monitoring will persist for the test system in order to know when something is broken, in this case coolOrange support is only notified in case of a failed test.

