#!/bin/bash

#!/bin/bash

############################################################
# 🌟 AWS RDS Temp Access Script
# ----------------------------------------------------------
# 🔧 Author: Mark Hugley
# 📅 Created: May 2025
# 📄 Purpose: Grant temporary 1-hour RDS access to AWS SSO 
#             users via dynamically created permission sets
# 💡 Notes:
#   - Requires AWS CLI v2 with SSO configured
#   - Region is hardcoded to us-east-1 (can be changed)
#   - Outputs success message with permission set name
############################################################


# Set Profile
echo ""
read -p "Enter your AWS profile name: " PROFILE_NAME
profile=$PROFILE_NAME

# Configurable variables
AWS_REGION="us-east-1"
INSTANCE_ARN=$(aws sso-admin list-instances --query "Instances[0].InstanceArn" --output text --profile "$profile")
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$profile")

echo "Welcome to the Temporary RDS Access Creator!"
echo "-------------------------------------------------"

# Step 1: List Users
echo "Fetching available users..."
USER_LIST=$(aws identitystore list-users \
 --identity-store-id $(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text --profile "$profile") \
 --region $AWS_REGION \
 --profile "$profile")

USER_NAMES=($(echo $USER_LIST | jq -r '.Users[].UserName'))
USER_IDS=($(echo $USER_LIST | jq -r '.Users[].UserId'))

echo ""
echo "Select a user to grant temporary RDS access:"
for i in "${!USER_NAMES[@]}"; do
  echo "$i) ${USER_NAMES[$i]}"
done

read -p "Enter the number of the user: " USER_INDEX

SELECTED_USER_NAME=${USER_NAMES[$USER_INDEX]}
SELECTED_USER_ID=${USER_IDS[$USER_INDEX]}

echo "You selected: $SELECTED_USER_NAME"
echo ""

# Step 2: List RDS Instances
echo "Fetching available RDS databases..."
RDS_LIST=$(aws rds describe-db-instances --region $AWS_REGION --profile "$profile")

DB_NAMES=($(echo $RDS_LIST | jq -r '.DBInstances[].DBInstanceIdentifier'))

if [ ${#DB_NAMES[@]} -eq 0 ]; then
  echo "No RDS instances found! Exiting."
  exit 1
fi

echo ""
echo "Select an RDS database:"
for i in "${!DB_NAMES[@]}"; do
  echo "$i) ${DB_NAMES[$i]}"
done

read -p "Enter the number of the RDS database: " DB_INDEX

SELECTED_DB_NAME=${DB_NAMES[$DB_INDEX]}

echo "You selected RDS database: $SELECTED_DB_NAME"
echo ""

# Step 3: Create Permission Set
USERNAME_SHORT=$(echo $SELECTED_USER_NAME | cut -d'@' -f1)
SUFFIX=$(date +%s)

PERMISSION_SET_NAME="Temp-${USERNAME_SHORT}-${SUFFIX}"
SESSION_DURATION="PT1H"

echo "Creating Permission Set: $PERMISSION_SET_NAME..."

CREATE_RESPONSE=$(aws sso-admin create-permission-set \
  --instance-arn $INSTANCE_ARN \
  --name "$PERMISSION_SET_NAME" \
  --session-duration $SESSION_DURATION \
  --description "Temporary 1-hour access to $SELECTED_DB_NAME for $SELECTED_USER_NAME" \
  --region $AWS_REGION \
  --profile "$profile")

PERMISSION_SET_ARN=$(echo $CREATE_RESPONSE | jq -r '.PermissionSet.PermissionSetArn')

if [ -z "$PERMISSION_SET_ARN" ]; then
  echo "Failed to create permission set. Exiting."
  exit 1
fi

echo "Created Permission Set ARN: $PERMISSION_SET_ARN"

# Step 4: Create and Attach Inline Policy
POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:DescribeDBClusters",
                "rds:DescribeGlobalClusters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:Connect"
            ],
      "Resource": "arn:aws:rds:$AWS_REGION:$ACCOUNT_ID:db:$SELECTED_DB_NAME"
    }
  ]
}
EOF
)

echo "$POLICY_JSON" > temp-rds-policy.json

echo "Attaching RDS access policy..."
aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn $INSTANCE_ARN \
  --permission-set-arn $PERMISSION_SET_ARN \
  --inline-policy file://temp-rds-policy.json \
  --region $AWS_REGION \
  --profile "$profile"

# Step 5: Assign the Permission Set to User
echo "Assigning Permission Set to User..."

aws sso-admin create-account-assignment \
  --instance-arn $INSTANCE_ARN \
  --target-id $ACCOUNT_ID \
  --target-type AWS_ACCOUNT \
  --permission-set-arn $PERMISSION_SET_ARN \
  --principal-type USER \
  --principal-id $SELECTED_USER_ID \
  --region $AWS_REGION \
  --profile "$profile"

# Cleanup
rm temp-rds-policy.json

echo ""
echo "-------------------------------------------------"
echo "✅ Success! $SELECTED_USER_NAME now has 1-hour access to RDS: $SELECTED_DB_NAME!"
echo "Permission Set Name: $PERMISSION_SET_NAME"
echo "Session will expire automatically after 1 hour."
echo "-------------------------------------------------"
