#!/bin/sh
export AWS_PAGER=""

USER_NAME=$1
TARGET_OU="ou-9ygv-pflaeqry"
CROSS_ACCOUNT_ROLE_NAME="GlobalUserOffboarderRole"

if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI missing. Attempting ephemeral installation..."
    cd /tmp
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    
    if ! command -v unzip >/dev/null 2>&1; then
        echo "Error: 'unzip' is not installed in this runner. Cannot install AWS CLI."
        exit 1
    fi

    unzip -q awscliv2.zip
    ./aws/install -i /tmp/aws-cli -b /tmp/bin >/dev/null 2>&1
    AWS_BIN="/tmp/bin/aws"
    rm -rf /tmp/awscliv2.zip /tmp/aws
else
    AWS_BIN=$(command -v aws)
fi
# ------------------------------------------

if [ -z "$USER_NAME" ]; then
    echo "Usage: ./cleanup.sh <username>"
    exit 1
fi

echo "-------------------------------------------------------"
echo "Starting Global Offboarding for: $USER_NAME"
echo "Target OU: $TARGET_OU"
echo "-------------------------------------------------------"

ID_STORE=$($AWS_BIN sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text)
if [ "$ID_STORE" != "None" ] && [ -n "$ID_STORE" ]; then
    SSO_USER_ID=$($AWS_BIN identitystore list-users --identity-store-id "$ID_STORE" \
      --filters AttributePath=UserName,AttributeValue="$USER_NAME" \
      --query "Users[0].UserId" --output text)

    if [ "$SSO_USER_ID" != "None" ] && [ -n "$SSO_USER_ID" ]; then
        $AWS_BIN identitystore delete-user --identity-store-id "$ID_STORE" --user-id "$SSO_USER_ID"
        echo "[SSO] Success: User deleted from Identity Center."
    fi
fi

ACCOUNTS=$($AWS_BIN organizations list-accounts-for-parent --parent-id "$TARGET_OU" --query "Accounts[?Status=='ACTIVE'].Id" --output text)

for ACC_ID in $ACCOUNTS; do
    echo "[Account: $ACC_ID] Assuming $CROSS_ACCOUNT_ROLE_NAME..."

    CREDENTIALS=$($AWS_BIN sts assume-role \
        --role-arn "arn:aws:iam::$ACC_ID:role/$CROSS_ACCOUNT_ROLE_NAME" \
        --role-session-name "OffboardingSession" \
        --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
        --output text 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "[Account: $ACC_ID] Error: Could not assume role. Skipping."
        continue
    fi

    export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | cut -d' ' -f1)
    export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | cut -d' ' -f2)
    export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | cut -d' ' -f3)

    IAM_CHECK=$($AWS_BIN iam get-user --user-name "$USER_NAME" 2>&1)
    
    if ! echo "$IAM_CHECK" | grep -q "NoSuchEntity"; then
        echo "[Account: $ACC_ID] Found local user. Removing access..."
        
        $AWS_BIN iam delete-login-profile --user-name "$USER_NAME" 2>/dev/null || true
        
        for key in $($AWS_BIN iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text); do
            $AWS_BIN iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
        done
        
        for policy in $($AWS_BIN iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[].PolicyArn" --output text); do
            $AWS_BIN iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$policy"
        done

        $AWS_BIN iam delete-user --user-name "$USER_NAME"
        echo "[Account: $ACC_ID] Success: User removed."
    else
        echo "[Account: $ACC_ID] User not found."
    fi

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
done

echo "-------------------------------------------------------"
echo "Offboarding Process Complete."