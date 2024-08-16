# Introduction

This project is about demoing how an Azure Function Sink Connector can be replaced with an HTTP Sink Connector without to call the same Azure function.

Azure functions can be authenticated in two ways:

1. The reserved query parameter ```code```, which exposes the secret in clear text.
2. The ```x-functions-key``` header, which is not exposed, since Azure requires ```https```.

The motivation for creating this repo is that, at the time of writing, the Azure Sink Function Connector only supports the query parameter which is not always acceptable, whereas the HTTP Sink Connector can be configured for either and can invoke Azure Functions as it an HTTP enpoint being invoked.

The code is the [TurbineRepair](https://learn.microsoft.com/en-us/azure/azure-functions/openapi-apim-integrate-visual-studio?tabs=isolated-process) example from Microsoft documentation but refitted to be used for Azure Function Sink connector which requires the function to accept a specific request format as documented [here](https://docs.confluent.io/kafka-connectors/azure-functions/current/overview.html). This required structure of the Azure Function Sink Connector also comes into play as the schema for the HTTP Sink Connector only contains the ```key``` and ```value``` but is not an array by default, so this needs to be addressed as well.

One change is the logger which logs the full url used to invoke the function, this will be important to verify how the authentication happened.

## Prerequisites

In order to test this project there are some requirements:

- Active Azure Subscription
- Docker Desktop: [link](https://www.docker.com/products/docker-desktop/)
- .Net 8.0 SDK: [link](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- Azure Function Core Tools: [link](https://github.com/Azure/azure-functions-core-tools)
- VS Code: [link](https://code.visualstudio.com/download)
- Azure Functions extensions for VS Code: [link](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)

## Getting started

First step is the Azure Deployment which can be done from VS Code as follows:

1. Create Azure Function App by pressing F1 and select ```> Azure Functions: Create Function App in Azure...(Advanced)```. You will be guided through a promt that will eventually deploy the code, the thing of importance for this demo later is the ```name``` of the app and that ```Application Insights``` is enabled.
2. Then Deploy the function code to the Azure Function App by pressing F1 and select ```> Azure Functions: Deploy to Function App...```.
3. Navigate to the Azure Function App in your browser and click the link to the function ```TurbineRepair```. Then enter the tab: ```Function Keys``` and copy that value of default ```key``` for later use.
4. Navigate to the ```Logs``` tab which will be empty for now, but we want to capture the invocation live which will trigger later.

> Important: Make sure this is a temporary key as it will be exposed in a url for this demo.

Second is to set up the Confluent Platform environment which consists of Broker, Connect, Schema Registry and Control Center.

1. Run the ```start.sh``` with two parameters ```name``` and ```key``` from the previous steps. This will setup the cluster and required resources for this demo and you should be able to see the connector configs in the output.
2. In two different terminals run the ```consume-results.sh``` and ```consume-errors.sh``` which will output the results or errors from the Azure Function invocation respectively. For detailed inspection use Control Center.
3. In a thrid terminal run ```produce-data.sh``` with ```1``` or ```2``` as inputs interchangably a few times. ```1``` will write the data to the topic feeding the Azure Function Sink Connector and ```2``` feeds the HTTP Sink Connector.

> Smoke Test: Results come within seconds and no errors should appear.

## Wrap up

For verification of the authentication mechanism, view the ```Logs``` tab and notice the urls that a logged. ```Trigger Url: /api/TurbineRepair?code=<secret>``` are from the Azure Function Sink Connector and ```Trigger Url: /api/TurbineRepair``` is from the HTTP Sink Connector (which uses the ```x-functions-key``` header).

Finally just a note on the structure. The key to recreate the request structure from the Azure function we can leverage the [InsertField](https://docs.confluent.io/platform/current/connect/transforms/insertfield.html) SMT to add the ```partition```, ```offset```, and ```timestamp``` fields to the structure. Note, this is only doable when using a structure (Avro, Json, Profobuf) so that is an additional constraint, so if the original value is just a string, this is not doable. However, in order to complete it we need to be able to send an array of strcutures, and in order to achieve this we need to set ```"batch.json.as.array": true``` on the HTTP Sink Connector.

Now the HTTP Sink Connector can be replaced the Azure Sink Connector without changing this Azure Function and is more secure.
