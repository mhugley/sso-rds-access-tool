# AWS RDS Temp Access

A CLI tool to grant temporary RDS access to AWS SSO users using AWS SSO permission sets. Great for secure, time-limited database access without managing IAM users directly.

---

## 🚀 Features

- Prompt-based CLI workflow
- Lists available AWS SSO users and RDS databases
- Creates temporary permission sets with 1-hour session duration
- Attaches inline policy for RDS access
- Assigns permission set to selected user automatically

---

## 🔧 Requirements

- AWS CLI v2
- AWS SSO profile configured (`aws configure sso`)
- jq (for JSON parsing)
- Bash 5.x+

---

## 🛠️ Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/your-org/aws-rds-temp-access.git
   cd aws-rds-temp-access

2. Ensure you've logged in with AWS SSO:

    aws sso login --profile your-sso-profile

3. Make the script executable:
    chmod +x grant_temp_rds_access.sh

## 🏃 Run
Run the script and follow the prompts:
./grant_temp_rds_access.sh

## 🐶 Example Output
Enter your AWS profile name: my-sso-profile
Fetching available users...
Select a user to grant temporary RDS access:
0) john.doe@example.com
1) jane.smith@example.com
...

Select an RDS database:
0) my-prod-db
1) staging-db
...

✅ Success! jane.smith@example.com now has 1-hour access to RDS: staging-db!
Permission Set Name: Temp-jane-1715971301

## 🧹 Cleanup
The permission set and assignment will expire after the session duration (1 hour). You can manually delete them via the AWS Console or CLI if needed.

## 📝 Notes
This tool assumes your AWS SSO profile is already configured in ~/.aws/config
Region is currently set to us-east-1 by default — update the script if needed
Permission set name is auto-generated using username and a timestamp