# Pre-requisites

# Ensure the AKS Preview features have been enabled for the Azure CLI
az extension add --name aks-preview
az extension update --name aks-preview

# Register the AAD Pod Identity Preview Feature and the AKS App Gateway Feature for the Azure Subscription
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
az feature register --name AKS-IngressApplicationGatewayAddon --namespace Microsoft.ContainerService

# NOTE: Feature registration takes awhile, around 30 mins. Ensure that the features are in a "Registered" state before continuing
# The commands below monitor the registration status of each feature. Re-run these until registration has completed
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-IngressApplicationGatewayAddon')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePodIdentityPreview')].{Name:name,State:properties.state}"

# Refresh the registration of the Microsoft.ContainerService for the Azure Subscription
az provider register --namespace Microsoft.ContainerService