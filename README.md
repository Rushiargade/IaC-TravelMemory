# MERN Stack Deployment on AWS (TravelMemory)

This repository contains the infrastructure automation and configuration management code required to deploy the [TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory) MERN stack application on AWS. 

## Project Architecture

### 1. Infrastructure as Code (Terraform)
- **VPC & Networking**: Configured an isolated AWS VPC (`10.0.0.0/16`) with two subnets:
  - **Public Subnet**: Connected to an Internet Gateway (hosting the React frontend and Node.js backend).
  - **Private Subnet**: Protected behind a NAT Gateway (hosting the MongoDB database).
- **EC2 Instances**: Launched a Web Server (public subnet) and a Database Server (private subnet) utilizing IAM instance profiles.
- **Security Groups**: 
  - `web_sg`: Allows incoming traffic on ports `80`, `443`, `3000` (React), `5000` (Node Backend), and `22` (SSH limited to Admin IP).
  - `db_sg`: Restricts access to port `27017` (MongoDB) exclusively from the Web Server Security Group.

### 2. Configuration Management (Ansible)
- **Web Server Setup (`web`)**:
  - Installed `Node.js`, `npm`, and `pm2`.
  - Cloned the repository and installed module dependencies for both frontend and backend.
  - Dynamically injected MongoDB URI via `.env` file pointing to the private DB instance.
  - Deployed both servers securely using `pm2`.
- **Database Server Setup (`db`)**:
  - Securely installed `MongoDB` and restricted bindings strictly to the internal network.
- **Security Hardening**:
  - Uncomplicated Firewall (`ufw`) applied on both machines explicitly allowing only defined ports.
  - Disabled root SSH logins system-wide.

## Directory Structure
```
.
├── terraform/
│   ├── main.tf              # Base infrastructure config
│   ├── variables.tf         # Parameterized variables
│   └── outputs.tf           # Provisioned endpoint outputs
├── ansible/
│   ├── playbook.yml         # Main automation playbook
│   └── inventory.ini        # Target lists configured via Terraform outputs
└── README.md
```

## How to Deploy

### Step 1: Provision Infrastructure
```bash
cd terraform
terraform init
terraform apply -auto-approve
```
*Note: This will output the Public IP of the web server and the Private IP of the db server.*

### Step 2: Configure System Dependencies
Update the IP addresses in `ansible/inventory.ini` based on the Terraform output.

```bash
cd ../ansible
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i inventory.ini playbook.yml -u ubuntu --private-key ~/.ssh/your-aws-key.pem
```

### Step 3: Access the Application
The React Application will be live at:
`http://<WEB_PUBLIC_IP>:3000`

The Node API will be active under:
`http://<WEB_PUBLIC_IP>:5000`

## Practical Deployment Notes & Challenges Resolved
- **Database Reliability**: Binding MongoDB to only `127.0.0.1` locally hindered the backend node from connecting to it from a different subnet. Explicitly modifying `/etc/mongodb.conf` to bind `0.0.0.0` inside the private subnet ensured internal traffic routing worked flawlessly while staying secure.
- **Background Processes**: The frontend build natively occupies the terminal blocking subsequent steps. We resolved this utilizing `pm2` daemon process managers for seamless deployments across boots.
- **Environmental Security**: IAM EC2 roles actively minimize passing heavy API secrets allowing components to run securely behind NATs.

---
*Created as part of the DevOps hands-on infrastructure planning.*
