================================================================
 VAULTCLOUD — DAY 1 ENGINEER ONBOARDING & STARTING CHECKLIST
================================================================
Welcome to VaultCloud. You are the first security engineer
hired here. This document tells you where to start.

Read the ops-incident-log.txt first.
That file tells you more about the real state of this system
than any architecture diagram ever will.

----------------------------------------------------------------
STEP 1 — GET THE APP RUNNING LOCALLY (30 minutes)
----------------------------------------------------------------
This tells you what you are actually securing before you
touch any AWS or security tooling.

  1. Clone the repo
  2. Run:  docker-compose up
  3. Once running, hit these endpoints and note what comes back:

     GET  http://localhost:5000/health
     GET  http://localhost:5000/api/v1/accounts
     GET  http://localhost:5000/api/v1/accounts/admin
     GET  http://localhost:5000/api/v1/accounts/admin'--
     POST http://localhost:5000/api/v1/login
          body: {"username":"admin","password":"admin123"}
     GET  http://localhost:5000/debug/config
     POST http://localhost:5000/debug/sql
          body: {"query":"SELECT * FROM accounts"}

  Document what each one returns. You will reference this
  when you write the assessment report.

----------------------------------------------------------------
STEP 2 — SECRETS SWEEP (1 hour)
----------------------------------------------------------------
Before anything else, find every credential in this codebase.

  Run TruffleHog:
    docker run --rm -v $(pwd):/repo \
      trufflesecurity/trufflehog:latest filesystem /repo

  Also manually check:
    - app/Dockerfile          (ENV lines)
    - configs/.env            (everything)
    - .github/workflows/      (hardcoded values)
    - infra/breach-zone/      (provider block + outputs + SSM)
    - .gitignore              (what should be ignored but isn't)

  For every credential found, answer three questions:
    a. What service does it access?
    b. What is the blast radius if it is already compromised?
    c. Where does it need to be rotated and moved to?

  Record all findings. This becomes Deliverable 1 of your
  Breach Zone Assessment Report.

----------------------------------------------------------------
STEP 3 — IAM AUDIT (1–2 hours)
----------------------------------------------------------------
Run the IAM audit script against your AWS account.
The script is in tools/iam-audit.py (you will write this).

  What to find:
    - Every role with AdministratorAccess or wildcard actions
    - Every IAM user without MFA
    - Every access key older than 90 days
    - Every trust policy that allows external assumption
    - Every unused permission that has not been used in 90 days

  Use IAM Access Analyser in the AWS console to cross-check.
  Do not just read the Terraform — check what is actually
  deployed. They may not match.

----------------------------------------------------------------
STEP 4 — POSTURE BASELINE WITH PROWLER (2–3 hours)
----------------------------------------------------------------
Install and run Prowler against the account:

  pip install prowler
  prowler aws --output-formats json html

  This takes 20–40 minutes for a small account.
  While it runs, read every file in infra/breach-zone/
  and list every misconfiguration you can spot manually
  before Prowler finishes.

  Compare your manual list to Prowler's output.
  The gap between what you spotted and what Prowler found
  is your current detection skill baseline.

  Export the Prowler results. Save the HTML report.
  This is your before score. You will re-run this at the
  end of Week 2 and compare.

----------------------------------------------------------------
STEP 5 — VULNERABILITY SCAN (1 hour)
----------------------------------------------------------------
Run Trivy on the application container:

  trivy image --severity HIGH,CRITICAL vaultcloud/api:latest

  Also scan the filesystem:
  trivy fs --severity HIGH,CRITICAL ./app

  For each Critical and High CVE:
    - Look it up on nvd.nist.gov manually
    - Note the affected package and fix version
    - Note whether the vulnerable code path is reachable
      in this application

  This gives you the starting CVE count.
  You will re-run this after remediation and show the delta.

----------------------------------------------------------------
STEP 6 — NETWORK EXPOSURE MAP (1 hour)
----------------------------------------------------------------
Look at infra/breach-zone/main.tf and draw (even on paper):

  - Which services are in which subnet
  - Which security group rules allow what traffic
  - Which services are publicly accessible
  - What would an attacker who reached the EC2 instance
    be able to reach from there

  Answer: Can an EC2 instance in this environment reach
  the RDS database directly? The Redis instance?
  The SSM parameters? Other EC2 instances?

  This becomes the before-state for your Zero Trust
  network diagram in Deliverable 2.

----------------------------------------------------------------
STEP 7 — DOCUMENT THE BREACH ZONE BASELINE
----------------------------------------------------------------
At the end of Day 1 you should have:

  [ ] App running locally — all endpoints tested and noted
  [ ] TruffleHog secrets scan output saved
  [ ] List of every credential found and its blast radius
  [ ] IAM audit findings documented
  [ ] Prowler HTML report saved (this is your before score)
  [ ] Trivy CVE list saved with NVD lookups for top 5
  [ ] Network exposure map drawn
  [ ] Incident log read and annotated with which project
      deliverable would have prevented each entry

Do not start remediating anything until this baseline
is complete. You cannot measure improvement without a
starting point.

----------------------------------------------------------------
WHAT YOU ARE BUILDING TOWARD
----------------------------------------------------------------
By the end of Week 2:
  - Zero Trust network enforced
  - IAM least privilege applied
  - All plaintext secrets rotated into Secrets Manager
  - Prowler score improved by at least 40%
  - All Critical and High CVEs patched

By the end of Week 1 of automation:
  - Five Lambda auto-remediations live
  - GuardDuty active and alerting
  - Step Functions IR workflow for high-severity findings

By the final demo:
  - Introduce a misconfiguration on screen
  - Watch it auto-remediate in under 5 minutes
  - Show the before/after posture scorecard
  - Red team the hardened environment yourself

----------------------------------------------------------------
ONE RULE FOR THE WHOLE PROJECT
----------------------------------------------------------------
Every remediation must be provable.
"I fixed it" is not a deliverable.
A before-scan, the fix, and an after-scan showing the
finding is closed — that is a deliverable.

Good luck.
================================================================
