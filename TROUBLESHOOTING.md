# EKS Deployment Troubleshooting Guide

## Issues Found and Fixed

### 1. **Missing AWS Load Balancer Controller**
**Problem**: The cluster couldn't provision AWS Load Balancers for services of type `LoadBalancer`.
**Solution**: Added AWS Load Balancer Controller installation to the GitHub Actions workflow.

### 2. **Missing OIDC Provider**
**Problem**: Service accounts couldn't assume IAM roles (required for IRSA).
**Solution**: Added OIDC identity provider creation in `eks_cluster.tf`.

### 3. **Incorrect Security Group Rules**
**Problem**: Security group only allowed ports 80/443 but MinIO runs on port 9000.
**Solution**: Added ingress rules for MinIO ports (9000, 9001) and internal VPC communication.

### 4. **Missing Subnet Tags**
**Problem**: AWS Load Balancer Controller couldn't discover subnets for load balancer placement.
**Solution**: Added required Kubernetes tags to subnets:
- `kubernetes.io/role/elb = 1`
- `kubernetes.io/cluster/<cluster-name> = shared`

### 5. **Outdated MinIO Configuration**
**Problem**: MinIO configuration used deprecated environment variables and lacked proper health checks.
**Solution**: Updated to use `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` and added health checks.

## Verification Steps

After deployment, verify the following:

1. **Check AWS Load Balancer Controller is running:**
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. **Check MinIO pods are running:**
   ```bash
   kubectl get pods -l app=minio
   ```

3. **Check service has external IP:**
   ```bash
   kubectl get svc minio-service
   ```

4. **Check load balancer in AWS Console:**
   - Go to EC2 > Load Balancers
   - Look for load balancer with your cluster name

## Alternative Deployment Options

### Option 1: Use ALB with Ingress (Recommended for production)
Uncomment the Ingress section in `minio-improved.yaml` and comment out the LoadBalancer service.

### Option 2: Use NodePort with manual Load Balancer
Change service type to `NodePort` and create an ALB manually pointing to worker nodes.

## Common Issues and Solutions

### Load Balancer Stuck in Pending
- Check AWS Load Balancer Controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
- Verify subnet tags are correct
- Check IAM permissions for the controller

### MinIO Not Accessible
- Verify security group rules allow traffic on MinIO ports
- Check if pods are running: `kubectl describe pod <minio-pod-name>`
- Verify service account annotations: `kubectl describe sa minio-serviceaccount`

### S3 Access Issues
- Check IAM role trust policy includes correct OIDC provider
- Verify service account is annotated with correct IAM role ARN
- Test S3 access from within the pod

## Security Considerations

1. **Restrict CIDR blocks**: Consider restricting `0.0.0.0/0` to specific IP ranges
2. **Enable HTTPS**: Add SSL/TLS termination at the load balancer
3. **Network policies**: Implement Kubernetes network policies for pod-to-pod communication
4. **Secrets management**: Consider using AWS Secrets Manager instead of Kubernetes secrets

## Cost Optimization

1. **Instance types**: Consider using spot instances for non-production
2. **Auto-scaling**: Enable cluster autoscaler for dynamic scaling
3. **Load balancer**: NLB is cheaper than ALB for simple use cases
4. **Storage**: Use gp3 volumes instead of gp2 for better price/performance
