# AzureLogAnalytics 💙 Managed Identity

Log Analytics is super powerful to collect data and give you insights on what's going on with your apps and resources. There is even an Azure Monitor Logs connector for Logic Apps.

⚡ Very unfortunately, the connector doesn't support authentication with a Managed Identity - which means that you'd need an app registration again, which comes with its own challenges on secret handling.

![Azure Monitor connector](media/azuremonitorconnector.png)

> 💡 Azure Log Analytics REST API to the rescue!

We can call the [Log Analytics REST API](https://docs.microsoft.com/en-us/rest/api/loganalytics/) from Logic Apps with the generic HTTP action - and authenticate with a Managed Identity. For this example, I chose a user-assigned Managed Identity, so that you can reuse this across resources, but of course you can go with a system-assigned Managed Identity as well.

You can find an example how to create a Logic App that queries Log Analytics with a user-assigned Managed Identity that has the [Log Analytics Reader](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#log-analytics-reader) assigned.

## Deployment

1. Fork and clone this repository
1. Browse to the root folder in your clone
1. Connect to the Azure subscription that you want this to run in
1. Run the `deploy.ps1` script
1. You will be prompted to provide
   - a location
   - a Resource group name
1. Check in the Azure Portal after you read the success-message `Resources deployed successfully, role assigned`

   - Resource group
   - Logic App
   - Azure Log Workspace
   - Managed Identity
![resource group](media/resource-group.png)

1. In the Logic App, the Authentication works with the Managed Identity
![LogicApps-auth](media/logicapp-auth.png)

1. Our Managed Identity has the `Log Analytics Reader` role assigned

![Managed Identity](media/ManagedIdentity-role.png)

💡 Please make sure that you insert a query into the Logic app that makes sense depending on your scenario.

## Questions?

If you have questions, want to use this, make it better - please do! Find me either on [twitter](https://twitter.com/LuiseFreese) or on [GitHub](https://github.com/luisefreese)

*sharing is caring*
