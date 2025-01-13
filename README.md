# Custom Image Builder

This tool allows you to build custom AMI's in AWS using Terraform. Follow the steps below to get started.

---

## 🚀 Getting Started

### 1. Clone the Repository
Clone the repository to your local machine:
```bash
git clone https://ajlab-gh/amibuilder
cd amibuilder
```

### 2. Initialize Terraform
Run the following command to initialize Terraform:
```bash
terraform init
```

### 3. Set AWS Environment Variables
Set your AWS credentials as environment variables. Replace `<YOUR_AWS_KEY>`, `<YOUR_AWS_SECRET>`, and `<YOUR_AWS_SESSION_TOKEN>` with your AWS details:
```bash
export AWS_ACCESS_KEY_ID="<YOUR_AWS_KEY>"
export AWS_SECRET_ACCESS_KEY="<YOUR_AWS_SECRET>"
export AWS_SESSION_TOKEN="<YOUR_AWS_SESSION_TOKEN>"
```

### 4. Create a Key Pair
Generate an SSH key pair to be used for instance authentication:
```bash
ssh-keygen -t rsa -b 2048 -f aws_key_pair
```

This will generate two files:
- `aws_key_pair` (private key)
- `aws_key_pair.pub` (public key)

Keep the private key (`aws_key_pair`) secure as it will be required to SSH into the instance.

### 5. Add Your Custom Image
Place your custom image in the root directory of the project. **The image must be in the `.out.OpenXen.zip` format.**

### 6. Build Your Image
Deploy the configuration by applying Terraform:
```bash
terraform apply
```
Confirm the deployment when prompted.

---

## 🛠️ Key Features
- **Customizable Deployment**: Modify the Terraform configuration to suit your image deployment needs.
- **AWS Integration**: Seamlessly integrates with AWS for image building and instance provisioning.
- **Secure Authentication**: Uses SSH key pairs for secure access.

---

## 📝 Notes

- Verify that your AWS IAM user has sufficient permissions to create key pairs, EC2 instances, and related resources.
- Store the private key (`aws_key_pair`) securely; it will be required for SSH access to the EC2 instance.
- Use the following command to clean up resources provisioned by Terraform when they're no longer needed:
  ```bash
  terraform destroy
  ```
- **Important**: Manually delete assets created by the EC2 host. Resources such as `snapshots` and `AMIs` will persist after running `terraform destroy`, as they are not managed directly by Terraform.

---

## 🤝 Contributing
Contributions are welcome! Fork the repo and submit a pull request with your enhancements.

---

## 📜 License
This project is licensed under the MIT License. See the `LICENSE` file for details.

---

All Credit to @mgiguere, Principal Cloud Architect, Fortinet Canada.
