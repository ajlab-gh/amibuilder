# Custom Image Builder

This tool allows you to build custom images for deployment using Terraform and AWS. Follow the steps below to get started.

---

## 🚀 Getting Started

### 1. Clone the Repository
Clone the repository to your local machine:
```bash
git clone https://ajlab-gh/custom-image
cd custom-image
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
- Ensure that your AWS IAM user has the necessary permissions to create key pairs, EC2 instances, and associated resources.
- Save the private key (`aws_key_pair`) in a secure location; it’s required for SSH access to the instance.
- Use `terraform destroy` to tear down resources when they're no longer needed:
  ```bash
  terraform destroy
  ```

---

## 🤝 Contributing
Contributions are welcome! Fork the repo and submit a pull request with your enhancements.

---

## 📜 License
This project is licensed under the MIT License. See the `LICENSE` file for details.

---

Happy Building! 🚀