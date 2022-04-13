[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Location,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    [string]
    $SubscriptionId = ""
)

if ($SubscriptionId -ne "") {
    az account set -s $SubscriptionId
    if (!$?) { 
        Write-Error "Unable to select $SubscriptionId as the active subscription."
        exit 1
    }
    Write-Host "Active Subscription set to $SubscriptionId"
} else {
    $Subscription = az account show | ConvertFrom-Json
    $SubscriptionId = $Subscription.id
    $SubscriptionName = $Subscription.name
    Write-Host "Active Subscription is $SubscriptionId ($SubscriptionName)"
}

Write-Host "Validating deployment location"
$ValidateLocation = az account list-locations --query "[?name=='$Location']" | ConvertFrom-Json
if ($ValidateLocation.Count -eq 0) {
    Write-Error "The location provided is not valid, the available locations for your account are:"
    az account list-locations --query [].name
    exit 1
}


Write-Host "Creating Resource Group"
az group create `
    --name $ResourceGroupName `
    --location $Location

Write-Host "Ensuring current user has contributor permissions to $ResourceGroupName resource group"

$me = az ad signed-in-user show | ConvertFrom-Json
$roleAssignments = az role assignment list --all --assignee $me.objectId --query "[?resourceGroup=='$ResourceGroupName' && roleDefinitionName=='Contributor'].roleDefinitionName" | ConvertFrom-Json
if ($roleAssignments.Count -eq 0) {
    Write-Host "Current user does not have contributor permissions to $ResourceGroupName resource group, attempting to assign contributor permissions"
    az role assignment create --assignee $me.objectId --role contributor --resource-group $ResourceGroupName
}
Write-Host "Deploying resources to the  $ResourceGroupName resource group and assigning built in role"
$DeployTimestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdTHmZ")
# Deploy
az deployment group create `
    --name "DeployLinkedTemplate-$DeployTimestamp" `
    --resource-group $ResourceGroupName `
    --template-file src/main.bicep `
    --verbose

if (!$?) { 
    Write-Error "An error occured during the bicep deployment."
    exit 1
}

Write-Host "Resources deployed successfully, built-in role assigned, now assigning Sites.ReadWrite.All permissions to Managed Identity"

$ManagedIdentity = az identity show --name 'Managed-Identity--Logging' --resource-group $ResourceGroupName | ConvertFrom-Json

$principalId = $ManagedIdentity.principalId
# Get current role assignments
$currentRoles = (az rest `
    --method get `
    --uri https://graph.microsoft.com/v1.0/servicePrincipals/$principalId/appRoleAssignments `
    | ConvertFrom-Json).value `
    | ForEach-Object { $_.appRoleId }

#Get resourceId for Graph API    
$graphResourceId = az ad sp list --display-name "Microsoft Graph" --query [0].objectId
#Get appRoleIds : Sites.ReadWrite.All
$graphId = az ad sp list --query "[?appDisplayName=='Microsoft Graph'].appId | [0]" --all

$sitesReadWriteAll = az ad sp show --id $graphId --query "appRoles[?value=='Sites.ReadWrite.All'].id | [0]" -o tsv

$appRoleIds = $sitesReadWriteAll
#Loop over all appRoleIds for Graph API
foreach ($appRoleId in $appRoleIds) {
    $roleMatch = $currentRoles -match $appRoleId
    if ($roleMatch.Length -eq 0) {
        # Add the role assignment to the principal
        $body = "{'principalId':'$principalId','resourceId':'$graphResourceId','appRoleId':'$appRoleId'}";
        az rest `
            --method post `
            --uri https://graph.microsoft.com/v1.0/servicePrincipals/$principalId/appRoleAssignments `
            --body $body `
            --headers Content-Type=application/json 
    }
}

Write-Host "Done"




