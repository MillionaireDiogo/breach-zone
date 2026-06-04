# VaultCloud - Breach Zone Starting Environment

> **You have just been hired as the first security engineer at VaultCloud.**
> The previous team moved fast. Security was "on the roadmap."
> This repository is what they left behind.

---

## Start here

Read [`docs/ops-incident-log.txt`](docs/ops-incident-log.txt) before anything else.
Then follow [`docs/DAY-1-CHECKLIST.md`](docs/DAY-1-CHECKLIST.md) step by step.

Do not start remediating. Do not start deploying new tooling.
Understand what you have inherited first.

---

## What each file is and what is wrong with it

**The app** (`app/app.py`) is a fintech API with five deliberate security problems: a SQL injection on the accounts endpoint, a `/debug/config` route returning live credentials and all environment variables, a `/debug/sql` route accepting raw SQL queries, plaintext password comparison on login, and an admin endpoint returning passwords and API keys to anyone with the hardcoded token. It runs locally with `docker-compose up` in under two minutes.

**The Terraform** (`infra/breach-zone/main.tf`) is the Breach Zone in infrastructure form. AdministratorAccess on both the EC2 role and the Lambda role, hardcoded AWS keys in the provider block, database in a public subnet with encryption off and backups at zero days, 0.0.0.0/0 on all ports for all security groups, four SSM parameters all stored as plaintext String not SecureString, and a public-read S3 bucket for both uploads and logs.

**The ops log** (`docs/ops-incident-log.txt`) is the most important file. It tells the story of a crypto miner running on the account for days, a Stripe live key exposed through the debug endpoint and never rotated, 6 weeks of transaction data lost because backups were manual, and GuardDuty findings being dismissed as "probably false positives." Every entry maps directly to a deliverable in the project.

**The Day 1 checklist** (`docs/DAY-1-CHECKLIST.md`) gives them six structured steps, run the app, do the secrets sweep, IAM audit, Prowler baseline, Trivy scan, network exposure map, with exact commands for each. They cannot start remediating until all six are done. That is the rule enforced in the checklist itself.

---

## Running the app locally

```bash
docker-compose up
```

The app runs on `http://localhost:5000`

Key endpoints to explore on Day 1:

| Endpoint | Method | What to note |
|---|---|---|
| `/health` | GET | Baseline, confirm the app is running |
| `/api/v1/accounts` | GET | What is returned without any authentication? |
| `/api/v1/accounts/admin` | GET | What fields come back for an admin account? |
| `/api/v1/accounts/admin'--` | GET | What does this return and why? |
| `/api/v1/login` | POST | body: `{"username":"admin","password":"admin123"}` |
| `/debug/config` | GET | Read every field that comes back |
| `/debug/sql` | POST | body: `{"query":"SELECT * FROM accounts"}` |

Document what each one returns before you change anything.

---

## What you are NOT doing

- You are not running `terraform apply` on the breach-zone infrastructure
- You are not deploying to AWS on Day 1
- You are not fixing anything until the full baseline is documented

The Terraform in `infra/breach-zone/main.tf` describes what is wrong with the current environment. You will use it to understand the problem, then build a correct version from scratch using proper modules.

---

## Tools to install before Day 1

```bash
# Secrets scanning
docker pull trufflesecurity/trufflehog:latest

# Container and filesystem vulnerability scanning
brew install aquasecurity/trivy/trivy      # macOS
apt install trivy                          # Linux

# Cloud posture management
pip install prowler

# AWS CLI
pip install awscli

# Terraform
brew install terraform                     # macOS
apt install terraform                      # Linux
```

---

## GitHub setup — for mentors

Push this repository to `github.com/expadox-lab/vaultcloud-breach-zone` and enable it as a template repository under Settings. Each mentee clicks **Use this template** to get their own copy under their own account with no connection to other mentees' work. The git history is part of the story, do not have mentees clone and reinitialise. The history of commits that show how this codebase got into this state is deliberate context.

---

*VaultCloud Breach Zone — Expadox Lab Cloud Security Engineering Project*
*This environment is intentionally misconfigured for educational purposes.*
