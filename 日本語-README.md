<!-- PROJECT SHIELDS -->
[![AWS EKS CI/CDパイプライン](https://github.com/rbnhd/pipeiline-eks-app/actions/workflows/eks_create_deploy.yaml/badge.svg)](https://github.com/rbnhd/pipeiline-eks-app/actions/workflows/eks_create_deploy.yaml) &nbsp;&nbsp; [![ライセンス: CC0 1.0 Universal](https://img.shields.io/badge/License-CC%201.0%20-lightgrey.svg)](./LICENSE)


<!-- PROJECT LOGO -->
<br />
<p align="center">

  <h1 align="center">MinIO on EKS</h1>

  <p align="center">
GitHub ActionsとTerraFormを用いてデプロイされるAmazon Elastic Kubernetes Service(EKS)上のMinIO
    <br />
    <br />
  </p>
</p>


## 目次

- [技術スタック](#技術スタック)
- [開始方法](#開始方法)
  - [前提条件](#前提条件)
  - [GitHubリポジトリのシークレット設定](#githubリポジトリのシークレット設定)
  - [使用法](#使用法)
- [パイプラインの説明](#パイプラインの説明)
- [貢献](#貢献)

## 技術スタック

パイプラインは以下の主要技術を使用します:

- **[Amazon Web Services (AWS)](https://aws.amazon.com/)**: アプリケーションとパイプラインのホスティングに使用されるクラウドプロバイダー。
- **[Terraform](https://www.terraform.io/)**: AWS上のインフラをプロビジョニングし、管理するためのInfrastructure as Code（IaC）ツール。
- **[Kubernetes (EKS)](https://aws.amazon.com/eks/)**: Dockerコンテナのデプロイメントを管理し、自動化するためのコンテナオーケストレーションプラットフォーム。ここではAmazon Elastic Kubernetes Service（EKS）を通じて使用されています。
- **[GitHub Actions](https://github.com/features/actions)**: ソフトウェア開発ワークフローを自動化するためのCI/CDプラットフォーム。
- **[MinIO](https://github.com/minio/minio)**: オブジェクトストレージ。Amazon S3クラウドストレージサービスとAPI互換性があります。

## 開始方法

このセクションでは、CI/CDパイプラインの設定とデプロイの手順を提供しています。

### 前提条件

- リソースの作成と管理に必要な権限を持つAWSアカウント。
- 必要なAWS資格情報をGitHubリポジトリのシークレットとして保存してください。

### GitHubリポジトリのシークレット設定

リポジトリレベルで以下のシークレットを設定する必要があります:

- `AWS_ACCESS_KEY_ID`: あなたのAWSアカウントのアクセスキーID。
- `AWS_SECRET_ACCESS_KEY`: あなたのAWSアカウントのシークレットアクセスキー。
- `AWS_REGION`: リソースをデプロイするAWSリージョン。
- `TF_STATE_BUCKET`: Terraformがその状態を保存するS3バケットの名前。
- `EKS_BUCKET_NAME`: MinIOサービスがアクセスするS3バケットの名前。
- `MINIO_ACCESS_KEY`: MinIOサービスのアクセスキー。
- `MINIO_SECRET_KEY`: MinIOサービスのシークレットキー。

さらに、リポジトリレベルで以下の変数を設定する必要があります:
- `AWS_REGION`: リソースをデプロイするAWSリージョン


### 使用法

必要なシークレットを設定したら、リポジトリの`main`または`releases/*`ブランチにプッシュしてパイプラインをデプロイできます。これにより、**[GitHub Actions](./.github/workflows/eks_create_deploy.yaml)** ワークフローがトリガーされ、アプリケーションがAWSのEKSクラスターにデプロイされます。



## パイプラインの説明

**:bangbang: 注意** パイプラインは**GitHub Actions**を使用して実行され、このリポジトリの[eks_create_deploy.yaml](./.github/workflows/eks_create_deploy.yaml)ファイルで定義されています。
  - パイプラインは`main`ブランチへの`push`または`pull_request`イベント、または`releases/*`パターンを持つ任意のブランチへの`push`でトリガーされます。
  - パイプラインは`README`、.`gitignore`、`screenshots/`への変更を**無視し**、これらのファイルへの変更では実行されません。

パイプラインには以下のステップが含まれています:

1. **Checkout**: GitHubリポジトリからコードをチェックアウトします。
2. **AWS資格情報の設定**: リポジトリシークレットに保存されたアクセスキーIDとシークレットアクセスキーを使用してAWSに認証します。
    ```
    uses: aws-actions/configure-aws-credentials@v4
    ```
3. **Terraformの設定**: ランナー上でTerraformを設定します。 (actions [hashicorp/setup-terraform](https://github.com/hashicorp/setup-terraform)を使用)
    ```
    uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: ${{ env.TF_VERSION }}
    ```
4. **Terraformの初期化と検証**: Terraformを初期化し、Terraformの状態ファイル用のバックエンドS3バケットを設定し、Terraformの設定を検証し、Terraformのプランを作成します。
    ```
    terraform init -backend-config="bucket=${TF_VAR_state_bucket}"
    terraform validate
    terraform plan
    ```
5. **Terraformの適用と出力の取得**: Terraformの設定を適用してAWS上にEKSクラスターと関連リソースを作成します。MinIOのIAMロールのARNをキャプチャし、それを環境変数として設定します。
    ```
    terraform apply -auto-approve
    echo "MINIO_IAM_ROLE_ARN=$(terraform output -raw minio_role_arn)" >> $GITHUB_ENV
    ```
6. **kubectlのインストールと設定**: ランナー上に`kubectl`をインストールし、EKSクラスターにアクセスするための情報でkubeconfigファイルを更新します。
    ```
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    ```
7. **MinIOサービスアカウントの作成**: Kubernetesのサービスアカウントを作成し、MinIOのIAMロールのARNでそれを注釈付けします。これは**minioが特定のS3バケットにアクセスする**ために重要です。このサービスアカウントはOIDCを使用してEKSクラスターに割り当てられたロールを引き受けます。
    ```
    kubectl create serviceaccount minio-serviceaccount
    kubectl annotate serviceaccount minio-serviceaccount eks.amazonaws.com/role-arn=$MINIO_IAM_ROLE_ARN
    ```
8. **MinIO認証情報シークレットの作成**: MinIOのアクセスキーとシークレットキーを保持するKubernetesシークレットを作成します。
    ```
    kubectl create secret generic minio-credentials --params VALUE
    ```
9. **EKS上でのMinIOのデプロイ**: Kubernetesのマニフェストを使用してEKSクラスターにMinIOサービスをデプロイします。
    ```
    kubectl apply -f PATH_TO_MINIO_DEPLOYMENT_FILE
    ```
10. **MinIOサービス用に作成されたロードバランサーのエンドポイントの取得**: MinIOサービス用に作成されたロードバランサーのエンドポイントを取得します。
    ```
    kubectl get svc minio-service
    ```
11. **Sleep & MinIOサービスの削除とTerraform Destroy**: 一定期間待った後、コストを避けるためにTerraformを使用してEKSクラスターと関連リソースを破壊します。
    ```
    if: always() 
    run: sleep 600 && terraform destroy -auto-approve
    ```


## スクリーンショット
スクリーンショットについては、こちらをご覧ください: [スクリーンショット](./screenshots/)

<br>


## 貢献

寄稿は歓迎されています。アイデアについて議論したり、あなたの変更をプルリクエストで開始したりするために、ぜひ問題を開いてください。

## ライセンス

このプロジェクトは、[CC0 1.0 Universal](./LICENSE)の条項の下でライセンスされています。
