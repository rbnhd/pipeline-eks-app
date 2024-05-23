#### EKS Cluster
# add the necessary IAM roles and policies for your EKS cluster.
resource "aws_iam_role" "eks_cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.name_prefix}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}


# define the EKS cluster itself.
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.name_prefix}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  version = "1.29" 

  vpc_config {
    subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

    # Specify additional subnet IDs if necessary
    # Public access is enabled by default; specify endpoint_private_access and endpoint_public_access as needed
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}




#### EKS Node Group
# Define an IAM role for the EKS node group.
resource "aws_iam_role" "eks_node_group" {
  name = "${var.name_prefix}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.name_prefix}-eks-node-group-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_instance_profile" "eks_node_group" {
  name = "${var.name_prefix}-eks-node-group-instance-profile"
  role = aws_iam_role.eks_node_group.name
}


# create the node group.
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.subnet.id]

  scaling_config {
    desired_size = 1
    max_size     = 1 # Maximum node pools
    min_size     = 1 # Minimum node pools
  }

  instance_types = ["t3.micro"] # Updated to the least expensive instance type

  depends_on = [
    aws_eks_cluster.eks_cluster,
  ]
}




#### IAM policy binding to allow EKS cluster to access S3 bucket
# define the IAM policy that allows access to the S3 bucket
resource "aws_iam_policy" "eks_s3_access" {
  name        = "${var.name_prefix}-eks-s3-access"
  description = "Policy to allow EKS node group to access a specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          // Include any other actions your application may need
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.eks_bucket}",
          "arn:aws:s3:::${var.eks_bucket}/*",
        ],
      },
    ],
  })
}

# attach this policy to the IAM role of the EKS node group:
resource "aws_iam_role_policy_attachment" "eks_s3_access" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = aws_iam_policy.eks_s3_access.arn
}