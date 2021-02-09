az acr login -n ACR_NAME # Change
docker push ACR_NAME.azurecr.io/weather-share # Change
az aks Get-Credentials -a --name AKS_CLUSTER_NAME -g RESOURCE_GROUP_NAME # Change
