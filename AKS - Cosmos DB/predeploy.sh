# Pre-requisites
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
az provider register -n Microsoft.ContainerService
az extension add --name aks-preview
az extension update --name aks-preview

az feature register --name AKS-IngressApplicationGatewayAddon --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerService

cd dotnet
docker build -t weather-share:latest .
docker image tag weather-share:latest ACR_NAME.azurecr.io/weather-share:latest # Change