# VaultCloud — Breach Zone Starting Environment

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

## What is in this repository

```
vaultcloud/
├── app/
│   ├── app.py              # Flask API — the application you are securing
│   ├── requirements.txt    # Dependencies (some with known CVEs)
│   └── Dockerfile          # Container definition
├── infra/
│   └── breach-zone/
│       └── main.tf         # The current AWS infrastructure — do not apply this
├── configs/
│   ├── .env                # Environment variables (should not be here)
│   └── aws-credentials-template.txt
├── .github/
│   └── workflows/
│       └── deploy.yml      # Current CI/CD pipeline
├── docker-compose.yml      # Run the app locally
├── docs/
│   ├── ops-incident-log.txt   # 5 months of operational history
│   └── DAY-1-CHECKLIST.md     # Where you start
└── .gitignore              # Note what is and isn't being ignored
```

---

## Running the app locally

```bash
docker-compose up
```

The app runs on `http://localhost:5000`

Key endpoints to explore on Day 1:
- `GET /health`
- `GET /api/v1/accounts`
- `GET /debug/config`
- `POST /debug/sql`

---

## What you are NOT doing

- You are not running `terraform apply` on the breach-zone infra
- You are not deploying to AWS on Day 1
- You are not fixing anything until you have documented the baseline

The Terraform in `infra/breach-zone/` describes what is wrong with
the current environment. You will use it to understand the problem,
then build a correct version from scratch.

---

## Tools you will need

Install these before Day 1:

```bash
# Secrets scanning
docker pull trufflesecurity/trufflehog:latest

# Container and filesystem vulnerability scanning
brew install aquasecurity/trivy/trivy      # macOS
# or: apt install trivy                    # Linux

# Cloud posture management
pip install prowler

# AWS CLI
pip install awscli

# Terraform (for reading and later building)
brew install terraform
```

---

*VaultCloud Breach Zone — Expadox Lab Cloud Security Engineering Project*
*This environment is intentionally misconfigured for educational purposes.*
