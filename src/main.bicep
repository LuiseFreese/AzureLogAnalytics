param AzureLogAnalytics_ManagedIdentity_name string = 'Managed-Identity--Logging'
param workflowName string = 'Logic-App--Logging'
param workspaceName string = 'Log-Analytics-Workspace--Logging'
param location string = resourceGroup().location
param rootUrl string = 'https://api.loganalytics.io'
param siteID string
param listId string

param roleDefinitionResourceId string = '73c42c96-874c-492b-b04d-ab87d138a893' //Reader


resource workspace 'microsoft.operationalinsights/workspaces@2021-12-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', AzureLogAnalytics_ManagedIdentity_name)}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {}
          }
        }
      }
  actions: {
    HTTP_create_item_in_list: {
      runAfter: {
        HTTP_get_logs: [
          'Succeeded'
        ]
      }
      type: 'Http'
      inputs: {
        authentication: {
          audience: 'https://graph.microsoft.com'
          identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', AzureLogAnalytics_ManagedIdentity_name)
          type: 'ManagedServiceIdentity'
        }
        body: {
          fields: {
            Title: '@{body(\'HTTP_get_logs\')?[\'tables\'][0]?[\'rows\'][0][0]}'
          }
        }
        headers: {
          'content-type': 'application/json'
        }
        method: 'POST'
        uri: 'https://graph.microsoft.com/v1.0/sites/${siteID}/lists/${listId}/items'
      }
    }
    HTTP_get_logs: {
      runAfter: {}
      type: 'Http'
      inputs: {
        authentication: {
          audience: rootUrl
          identity:resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/', AzureLogAnalytics_ManagedIdentity_name)
          type: 'ManagedServiceIdentity'
        }
        method: 'GET'
        queries: {
          query: 'print "42"'
        }
        uri: '${rootUrl}/v1/workspaces/${workspace.properties.customerId}/query'
      }
    }
  }
  outputs: {}
  }
  parameters: {}
  }
}

resource logAnalyticsReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: roleDefinitionResourceId //Reader
}

resource AzureLogAnalytics_ManagedIdentity_name_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: AzureLogAnalytics_ManagedIdentity_name
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: workspace
  name: guid(resourceGroup().id, AzureLogAnalytics_ManagedIdentity_name_resource.id, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: logAnalyticsReaderRoleDefinition.id
    principalId: AzureLogAnalytics_ManagedIdentity_name_resource.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output workspace object = workspace


