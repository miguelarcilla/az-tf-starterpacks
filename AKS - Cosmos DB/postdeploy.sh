# Enter the dotnet directory and build the sample API, tagging it with the Azure Container Registry
cd dotnet
docker build -t weather-share:latest .
docker image tag weather-share:latest ACR_NAME.azurecr.io/weather-share:latest # Change

# Return to the base directory and push the sample API container image to the ACR
cd ..
az acr login -n ACR_NAME # Change
docker push ACR_NAME.azurecr.io/weather-share # Change

# Enter the AKS Kubernetes context and apply the weather-share YAML definition
az aks Get-Credentials -a --name AKS_CLUSTER_NAME -g RESOURCE_GROUP_NAME # Change
kubectl apply -f aks/weather-share.yaml --namespace weather-share