#!/bin/bash
USER_NAME=$1

echo "-------------------------------------------------------"
echo "Starting Offboarding for: $USER_NAME"
echo "-------------------------------------------------------"

ID_STORE=$(aws sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text)

if [ "$ID_STORE" != "None" ]; then
    SSO_USER_ID=$(aws identitystore list-users --identity-store-id $ID_STORE \
      --filters AttributePath=UserName,AttributeValue=$USER_NAME \
      --query "Users[0].UserId" --output text)

    if [ "$SSO_USER_ID" != "None" ] && [ -n "$SSO_USER_ID" ]; then
        aws identitystore delete-user --identity-store-id $ID_STORE --user-id $SSO_USER_ID
        echo "[SSO] Success: User deleted."
    fi
fi

IAM_CHECK=$(aws iam get-user --user-name "$USER_NAME" 2>&1)

if [[ ! $IAM_CHECK =~ "NoSuchEntity" ]]; then
    aws iam delete-login-profile --user-name "$USER_NAME" 2>/dev/null
    
    for key in $(aws iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text); do
        aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
    done
    
    for policy in $(aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[].PolicyArn" --output text); do
        aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$policy"
    done

    aws iam delete-user --user-name "$USER_NAME"
    echo "[IAM] Success: User $USER_NAME removed."
fi