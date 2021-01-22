az acr login -n pbzxacr
docker push pbzxacr.azurecr.io/weather-share
az aks Get-Credentials -a --name pbzx-aks -g pbzx-rg

kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment.yaml
kubectl create serviceaccount --namespace kube-system tiller-sa
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller-sa

helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

helm install -f aks/helm-config.yaml application-gateway-kubernetes-ingress/ingress-azure --generate-name
kubectl apply -f aks/weather-share.yaml