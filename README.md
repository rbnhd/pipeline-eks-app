<!-- PROJECT SHIELDS -->
[![AWS EKS CI/CD Pipeline](https://github.com/rbnhd/pipeiline-eks-app/actions/workflows/eks_create_deploy.yaml/badge.svg)](https://github.com/rbnhd/pipeiline-eks-app/actions/workflows/eks_create_deploy.yaml) &nbsp;&nbsp; [![License: CC0 1.0 Universal](https://img.shields.io/badge/License-CC%201.0%20-lightgrey.svg)](./LICENSE)


<!-- PROJECT LOGO -->
<br />
<p align="center">

  <h1 align="center">MinIO on EKS</h1>

  <p align="center">
MinIO on Amazon Elastic Kubernetes Service (EKS) deployed with GitHub Actions and TerraForm
    <br />
    <br />
  </p>
</p>


## Table of Contents

- [Tech Stacks](#tech-stacks)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Set GitHub Repository Secrets](#set-github-repository-secrets)
  - [Usage](#usage)
- [Pipeline Explanation](#pipeline-explanation)
- [Contributing](#contributing)

## Tech Stacks

The pipeline uses the following key technologies:

- **[Amazon Web Services (AWS)](https://aws.amazon.com/)**: The cloud provider used for hosting the application and the pipeline.
- **[Terraform](https://www.terraform.io/)**: An Infrastructure as Code (IaC) tool used to provision and manage the infrastructure on AWS.
- **[Kubernetes (EKS)](https://aws.amazon.com/eks/)**: A container orchestration platform, used here via Amazon Elastic Kubernetes Service (EKS), to manage and automate the deployment of the Docker containers.
- **[GitHub Actions](https://github.com/features/actions)**: A CI/CD platform used to automate the software development workflow.

## Getting Started

Instructions for setting up and deploying the CI/CD pipeline are provided in this section.

### Prerequisites

- An AWS account with necessary permissions to create and manage resources.
- Ensure that the necessary AWS credentials are stored as secrets in your GitHub repository. 

### Set GitHub Repository Secrets

You need to set the following secrets at the repository level:

- `AWS_ACCESS_KEY_ID`: The access key ID for your AWS account.
- `AWS_SECRET_ACCESS_KEY`: The secret access key for your AWS account.
- `AWS_REGION`: The AWS region in which to deploy the resources.
- `TF_STATE_BUCKET`: The name of the S3 bucket where Terraform will store its state.
- `EKS_BUCKET_NAME`: The name of the S3 bucket that the MinIO service will have access to.
- `MINIO_ACCESS_KEY`: The access key for the MinIO service.
- `MINIO_SECRET_KEY`: The secret key for the MinIO service.

In addition, you need to set the following variables at the repository level:
- `AWS_REGION`: The AWS region in which to deploy the resources


### Usage

Once you've set the necessary secrets, you can deploy the pipeline by pushing to the `main` or `releases/*` branches of your repository. This will trigger the GitHub Actions workflow, which will then deploy your application to an EKS cluster on AWS.



## Pipeline Explanation

The pipeline is defined in the [eks_create_deploy.yaml](./.github/workflows/eks_create_deploy.yaml) file in this repository.
  - The pipeline is triggered on every `push` or `pull_request` event to the `main` branch or `push` to any branch with `releases/*` pattern. 
  - The pipeline **ignores changes** to `README`, .`gitignore` or `screenshots/` and doesn't run on changes to these files for obvious reasons.

The pipeline includes the following steps:

1. **Checkout**: Checks out the code from the GitHub repository.
2. **Configure AWS Credentials**: Authenticates to AWS using the access key ID and secret access key stored in the repository secrets.
    ```
    uses: aws-actions/configure-aws-credentials@v4
    ```
3. **Setup Terraform**: Sets up Terraform on the runner.  (uses actions [hashicorp/setup-terraform](https://github.com/hashicorp/setup-terraform))
    ```
    uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: ${{ env.TF_VERSION }}
    ```
4. **Terraform Init and validate**: Initializes Terraform, sets the backend S3 bucket for terraform state file, validates the Terraform configuration, and creates a Terraform plan.
    ```
    terraform init -backend-config="bucket=${TF_VAR_state_bucket}"
    terraform validate
    terraform plan
    ```
5. **Terraform Apply and get Output**: Applies the Terraform configuration to create the EKS cluster and associated resources on AWS. Captures the ARN of the MinIO IAM role and sets it as an environment variable.
    ```
    terraform apply -auto-approve
    echo "MINIO_IAM_ROLE_ARN=$(terraform output -raw minio_role_arn)" >> $GITHUB_ENV
    ```
6. **Install and configure kubectl**: Installs `kubectl` on the runner and updates the kubeconfig file with the information to access the EKS cluster.
    ```
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    ```
7. **Create MinIO service account**: Creates a Kubernetes service account and annotates it with the ARN of the MinIO IAM role. This is important for minio to access a specific S3 bucket. This service account used OIDC to assume the role assigned to the EKS cluster.
    ```
    kubectl create serviceaccount minio-serviceaccount
    kubectl annotate serviceaccount minio-serviceaccount eks.amazonaws.com/role-arn=$MINIO_IAM_ROLE_ARN
    ```
8. **Create MinIO credentials secret**: Creates a Kubernetes secret to hold the MinIO access key and secret key.
    ```
    kubectl create secret generic minio-credentials
    ```
9. **Deploy MinIO on EKS**: Deploys the MinIO service to the EKS cluster using the Kubernetes manifests.
    ```
    kubectl apply -f PATH_TO_MINIO_DEPLOYMENT_FILE
    ```
10. **Get the endpoint of the load balancer created for the MinIO service**: Retrieves the endpoint of the load balancer that is created for the MinIO service.
    ```
    kubectl get svc minio-service
    ```
11. **Sleep & then Delete MinIO Service and Terraform Destroy**: Waits for a period, and then destroys the EKS cluster and associated resources using Terraform to avoid costs.. 
    ```
    if: always() 
    run: sleep 600 && terraform destroy -auto-approve
    ```


## Screenshots
For screenshots, see: [Screenshots](./screenshots/)

<br>


## Contributing

Contributions are welcome. Please open an issue to discuss your ideas or initiate a pull request with your changes.

## License

This project is licensed under the terms of the [CC0 1.0 Universal](./LICENSE).