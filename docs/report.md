# Implementation Report
## MERN Stack Deployment on AWS using Terraform & Ansible

---

## 1. Overview

This report documents the end-to-end deployment of the **TravelMemory** MERN stack application on Amazon Web Services (AWS). The deployment was fully automated using:
- **Terraform** for Infrastructure as Code (IaC)
- **Ansible** for Configuration Management and Application Deployment

The TravelMemory app allows users to log and browse their travel memories, built using **MongoDB, Express.js, React, and Node.js**.

---

## 2. Architecture Diagram

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │  AWS VPC        │
                    │  10.0.0.0/16   │
                    └───────┬────────┘
                            │
           ┌────────────────┴──────────────────┐
           │                                   │
  ┌────────▼──────────┐             ┌──────────▼───────────┐
  │  Public Subnet     │             │   Private Subnet      │
  │  10.0.1.0/24      │             │   10.0.2.0/24        │
  │                   │             │                       │
  │  ┌─────────────┐  │             │  ┌─────────────────┐  │
  │  │ Web Server  │  │◄────────────►  │  DB Server       │  │
  │  │ (EC2 t2.micro)│  │  27017 only │  │  (EC2 t2.micro) │  │
  │  │             │  │             │  │                 │  │
  │  │ React :3000 │  │             │  │  MongoDB :27017 │  │
  │  │ Node  :5000 │  │             │  │                 │  │
  │  └─────────────┘  │             │  └─────────────────┘  │
  └────────────────────┘             └──────────────────────┘
           │
  ┌────────▼─────────┐
  │ Internet Gateway │
  └──────────────────┘
           │
     Public Internet
```

---

## 3. Infrastructure Setup (Terraform)

### 3.1 AWS Resources Created

| Resource | Name | Details |
|---|---|---|
| VPC | travelmemory-vpc | CIDR: 10.0.0.0/16 |
| Public Subnet | travelmemory-public-subnet | CIDR: 10.0.1.0/24, AZ: us-east-1a |
| Private Subnet | travelmemory-private-subnet | CIDR: 10.0.2.0/24, AZ: us-east-1a |
| Internet Gateway | travelmemory-igw | Attached to VPC |
| NAT Gateway | travelmemory-nat | Deployed in Public Subnet |
| Elastic IP | - | Allocated for NAT Gateway |
| Route Table (Public) | travelmemory-public-rt | 0.0.0.0/0 → IGW |
| Route Table (Private) | travelmemory-private-rt | 0.0.0.0/0 → NAT |
| Security Group (Web) | web-server-sg | Inbound: 22, 3000, 5000 |
| Security Group (DB) | db-server-sg | Inbound: 27017, 22 from Web SG only |
| EC2 Instance (Web) | travelmemory-web | t2.micro, Ubuntu 22.04, Public Subnet |
| EC2 Instance (DB) | travelmemory-db | t2.micro, Ubuntu 22.04, Private Subnet |
| IAM Role | travelmemory_ec2_role | EC2 assume role policy |
| IAM Instance Profile | travelmemory_ec2_profile | Attached to both instances |

### 3.2 Terraform Workflow

```bash
$ cd terraform
$ terraform init
# Initializes provider plugins and backend

$ terraform plan
# Shows resources to be created

$ terraform apply -auto-approve
# Applies the infrastructure changes
```

**Terraform Outputs:**
```
web_public_ip   = "54.x.x.x"
db_private_ip   = "10.0.2.x"
ssh_command_web = "ssh -i ~/.ssh/my-aws-key.pem ubuntu@54.x.x.x"
```

---

## 4. Configuration & Deployment (Ansible)

### 4.1 Ansible Architecture

| Component | Scope | Key Tasks |
|---|---|---|
| Common Hardening | All hosts | apt upgrade, ufw, fail2ban, SSH hardening |
| Web Server Play | `[web]` group | Node.js, NPM, PM2, git clone, build & serve app |
| DB Server Play | `[db]` group | MongoDB install, bind config, user creation |

### 4.2 Web Server Deployment Steps

1. Update package cache and upgrade OS packages
2. Configure UFW (ports 22, 3000, 5000)
3. Install Node.js v18 via NodeSource repository
4. Install PM2 process manager globally
5. Clone `TravelMemory` repository from GitHub
6. Install backend (`npm install`)
7. Create `.env` with `MONGO_URI` pointing to private DB IP
8. Start backend via PM2: `pm2 start index.js --name travelmemory-backend`
9. Install frontend (`npm install`)
10. Set `REACT_APP_BACKEND_URL` in frontend `.env`
11. Build production frontend: `npm run build`
12. Serve frontend at port 3000 using `serve` + PM2
13. Register PM2 as a systemd startup service

### 4.3 Database Server Deployment Steps

1. Configure UFW (port 27017 restricted to `10.0.1.0/24`)
2. Install MongoDB 6.0 via official APT repository
3. Modify `/etc/mongod.conf` to bind `0.0.0.0` (accessible within VPC)
4. Start and enable `mongod` service
5. Create application user `tmuser` with `readWrite` on `travelmemory` database

### 4.4 Ansible Run Command

```bash
$ cd ansible
$ ansible-playbook -i inventory.ini playbook.yml
```

---

## 5. Application Component Interaction

```
  Browser (Client)
       │
       │  HTTP :3000
       ▼
  React Frontend (Web Server - Public IP)
       │
       │  HTTP API Calls :5000
       ▼
  Node/Express Backend (Web Server - Same Host)
       │
       │  MongoDB Protocol :27017 (via Private VPC Network)
       ▼
  MongoDB (DB Server - Private IP 10.0.2.x)
```

- The **React app** is served statically via `serve` listening on port `3000`.
- It makes API calls to the **Express backend** on port `5000` (same public IP).
- The **Node.js backend** connects to **MongoDB** at the private IP through the VPC's internal routing — never exposed to the internet.

---

## 6. Security Measures Implemented

| Measure | Implementation |
|---|---|
| SSH Key-Based Auth Only | `PasswordAuthentication no` in sshd_config |
| Root SSH Login Disabled | `PermitRootLogin no` in sshd_config |
| UFW Firewall | Default deny, allow only required ports |
| Fail2Ban | Installed and enabled to block brute-force SSH attempts |
| DB not internet-exposed | MongoDB in private subnet, no public IP |
| DB port restricted | Port 27017 only accessible from Web SG inside VPC |
| Bastion / ProxyJump | SSH to DB server tunneled through Web Server |
| IAM Roles | EC2 instances use IAM roles (no hardcoded AWS keys) |
| MongoDB Auth | App uses dedicated DB user with limited privileges |

---

## 7. Challenges & Resolutions

| Challenge | Resolution |
|---|---|
| MongoDB binding to localhost blocked cross-host access | Set `bindIp: 0.0.0.0` in `mongod.conf`; UFW restricts access by subnet |
| React build blocking terminal | Used PM2 to serve the static build folder in background |
| SSH to private DB instance | ProxyJump via Web (bastion) in Ansible SSH args |
| Environment variable injection | Used Ansible `copy` module with templated `.env` files |
| NPM CI flag causing build failure | Set `CI=false` in npm build environment |

---

## 8. Screenshots

See `docs/screenshots/` folder for:
- `01_terraform_init.png` — Terraform initialization output
- `02_terraform_apply.png` — Infrastructure creation output
- `03_ansible_playbook_run.png` — Ansible playbook run 
- `04_app_frontend.png` — TravelMemory React App running
- `05_backend_api.png` — Backend API health check
- `06_aws_console_vpc.png` — VPC configuration in AWS Console
- `07_aws_console_ec2.png` — EC2 instances in AWS Console

---

## 9. Repository Structure

```
IaC-TravelMemory/
├── terraform/
│   ├── main.tf              # VPC, Subnets, IGW, NAT, SGs, EC2, IAM
│   ├── variables.tf         # Configurable variables
│   └── outputs.tf           # Public IP, SSH command outputs
├── ansible/
│   ├── ansible.cfg          # Ansible global configuration
│   ├── inventory.ini        # Host definitions (web + db)
│   └── playbook.yml         # Full deployment playbook
├── docs/
│   ├── report.md            # This implementation report
│   └── screenshots/         # Assignment screenshots
└── README.md                # Quick start guide
```

---

*Report prepared as part of DevOps Assignment: MERN Stack Deployment on AWS with Terraform & Ansible.*
