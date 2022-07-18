# Post-deployment Testing Commands

# Manual workaround
### Navigate to portal.azure.com and activate the AGIC feature. 
### It can be found in the AKS Resource under Networking. Select the newly created App Gateway in the drop-down to prevent creating a new resource

# Enter the AKS Kubernetes context and apply the weather-share YAML definition
az aks Get-Credentials -a --name pare-aks -g pare-rg # Change
kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml