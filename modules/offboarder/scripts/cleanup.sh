#!/bin/sh
USER_NAME=$1
TARGET_OU="ou-9ygv-pflaeqry"
CROSS_ACCOUNT_ROLE_NAME="GlobalUserOffboarderRole"

if [ -z "$USER_NAME" ]; then
    echo "Usage: ./cleanup.sh <username>"
    exit 1
fi

echo "-------------------------------------------------------"
echo "Starting Global Offboarding for: $USER_NAME"
echo "Target OU: $TARGET_OU"
echo "-------------------------------------------------------"

ID_STORE=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text)
if [ "$ID_STORE" != "None" ] && [ -n "$ID_STORE" ]; then
    SSO_USER_ID=$(aws identitystore list-users --identity-store-id "$ID_STORE" \
      --filters AttributePath=UserName,AttributeValue="$USER_NAME" \
      --query "Users[0].UserId" --output text)

    if [ "$SSO_USER_ID" != "None" ] && [ -n "$SSO_USER_ID" ]; then
        aws identitystore delete-user --identity-store-id "$ID_STORE" --user-id "$SSO_USER_ID"
        echo "[SSO] Success: User deleted from Identity Center."
    fi
fi

ACCOUNTS=$(aws organizations list-accounts-for-parent --parent-id "$TARGET_OU" --query "Accounts[?Status=='ACTIVE'].Id" --output text)

for ACC_ID in $ACCOUNTS; do
    echo "[Account: $ACC_ID] Assuming role..."

    CREDENTIALS=$(aws sts assume-role \
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

    IAM_CHECK=$(aws iam get-user --user-name "$USER_NAME" 2>&1)
    
    if ! echo "$IAM_CHECK" | grep -q "NoSuchEntity"; then
        echo "[Account: $ACC_ID] Found local user. Removing access..."
        
        aws iam delete-login-profile --user-name "$USER_NAME" 2>/dev/null || true
        
        for key in $(aws iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text); do
            aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
        done
        
        for policy in $(aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[].PolicyArn" --output text); do
            aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$policy"
        done

        aws iam delete-user --user-name "$USER_NAME"
        echo "[Account: $ACC_ID] Success: User removed."
    else
        echo "[Account: $ACC_ID] User not found."
    fi

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
done

echo "-------------------------------------------------------"
echo "Offboarding Process Complete."