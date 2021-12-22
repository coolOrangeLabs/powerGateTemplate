[Menu](../README.md) [Home](./home.md)

## Technology: REST webservices

We have created a public [Postman](https://www.postman.com/) collection to make it simple what we as coolOrange expect:
+ Read the [webservice documentation here](https://documenter.getpostman.com/view/449025/UUxzB87S)
+ To run the requests: [![Open in Postman the collection here](https://run.pstmn.io/button.svg)](https://app.getpostman.com/run-collection/449025-2a87fae5-a69a-44fa-b87e-8543f21a7688?action=collection%2Ffork&collection-url=entityId%3D449025-2a87fae5-a69a-44fa-b87e-8543f21a7688%26entityType%3Dcollection%26workspaceId%3Dada86f7b-de1a-46bd-9f82-5c9689139a8d)

### REST Authentication

We expect a [BASIC authentication](https://en.wikipedia.org/wiki/Basic_access_authentication):
+ In the Postman application the authentication is configurable via GUI, but at the end it sets the headers in each request:

![image](https://user-images.githubusercontent.com/36075173/135048951-bbedc268-8570-4b9d-8d55-c9eaaea282b4.png)

![image](https://user-images.githubusercontent.com/36075173/135049041-80d046af-88c1-4163-b1b3-911299539350.png)

### REST operations in Postman

You can select on the left side the different operations for items, boms and documents in Postman:
+ In `POST` _(Create)_ requests be aware of the `Auth`, `Headers` and `Body` tabs
+ In `PATCH` _(Update)_ requests be aware of the `Auth`, `Headers` and `Body` tabs
+ In `GET` _(Read)_ requests be aware of the `Auth` and `Headers` tabs

![image](https://user-images.githubusercontent.com/36075173/135065555-520129a0-943a-431e-aea5-3d4bd975e521.png)

