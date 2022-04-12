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

Write-Host "Resources deployed successfully, role assigned"
