# Terraform starter for Multi Containerized Application

Azure Terraform environments for small, self-contained applications.Deploys a Kubernetes cluster on AKS with multi containerized apps


## Contribution Guide

1. Fork the repository

2. Clone the repository

```
git clone https://github.com/miguelarcilla/az-tf-starterpacks.git
```

3. Create Feature branch and checkout
   _Replace <BRANCH_NAME> with meaningful name. For an example navbar. See the guide for the more details [Link](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow)_

```
git checkout -b feature/<BRANCH_NAME>
```

4. Add your changes

5. Stage Changes and commit

```
git add .
git commit -m "<Commit message>"
```

6. Push Changes

```
git push --set-upstream origin feature/<BRANCH_NAME>
```

7. Make a Pull Request.
   _See the guide for more details [Link](https://docs.github.com/en/free-pro-team@latest/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request)_


## Development 

### PreRequisites

Register the Below modules under the subscription that you will be working with,
```
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
az provider register -n Microsoft.ContainerService
az extension add --name aks-preview
az extension update --name aks-preview --debug
 
az feature register --name AKS-IngressApplicationGatewayAddon --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerService
```

### Execution

Step 1 : Rename the azure container registry name in the varaibles.tf file to unique one "variable "acr_name" under the folder "AKS - Cosmos DB"

Step 2 : Add a file named "terraform.tfvars" to the same directory as "main.tf" and define the variables such as
subscription_id="yoursubId"
solution_prefix="isvstudy"

Step 3 : Make sure you have installed  [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) in your machine and set the correct path

step 4 : Navigate to the AKS - Cosmos DB folder Initialize the working directory with the command
terraform init

Step 5 : Apply the plan stored in the terraform plan
terraform apply

step 6 : Validate the Azure resources created in your subscription with the ones defined in the plan

## Further help

To get more help on the project create an issue [here](https://github.com/miguelarcilla/az-tf-starterpacks/issues).
