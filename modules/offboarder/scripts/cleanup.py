import boto3
import sys
import os

user_name = sys.argv[1]
target_ou = "ou-9ygv-pflaeqry"
role_name = "GlobalUserOffboarderRole"

def cleanup_iam(session, account_id):
    iam = session.client('iam')
    try:
        iam.get_user(UserName=user_name)
        print(f"[{account_id}] Found user. Cleaning up...")
        
        try: iam.delete_login_profile(UserName=user_name)
        except: pass
        
        keys = iam.list_access_keys(UserName=user_name)['AccessKeyMetadata']
        for k in keys:
            iam.delete_access_key(UserName=user_name, AccessKeyId=k['AccessKeyId'])
            
        policies = iam.list_attached_user_policies(UserName=user_name)['AttachedPolicies']
        for p in policies:
            iam.detach_user_policy(UserName=user_name, PolicyArn=p['PolicyArn'])
            
        iam.delete_user(UserName=user_name)
        print(f"[{account_id}] Success: User removed.")
    except iam.exceptions.NoSuchEntityException:
        print(f"[{account_id}] User not found.")

sso_admin = boto3.client('sso-admin')
id_store_id = sso_admin.list_instances()['Instances'][0]['IdentityStoreId']
ids = boto3.client('identitystore')
user = ids.list_users(IdentityStoreId=id_store_id, Filters=[{'AttributePath': 'UserName', 'AttributeValue': user_name}])
if user['Users']:
    ids.delete_user(IdentityStoreId=id_store_id, UserId=user['Users'][0]['UserId'])
    print("[SSO] Success: User deleted.")

org = boto3.client('organizations')
accounts = org.list_accounts_for_parent(ParentId=target_ou)['Accounts']
sts = boto3.client('sts')

for acc in accounts:
    if acc['Status'] != 'ACTIVE': continue
    acc_id = acc['Id']
    print(f"--- Processing Account: {acc_id} ---")
    
    try:
        assumed = sts.assume_role(
            RoleArn=f"arn:aws:iam::{acc_id}:role/{role_name}",
            RoleSessionName="OffboardingSession"
        )['Credentials']
        
        session = boto3.Session(
            aws_access_key_id=assumed['AccessKeyId'],
            aws_secret_access_key=assumed['SecretAccessKey'],
            aws_session_token=assumed['SessionToken']
        )
        cleanup_iam(session, acc_id)
    except Exception as e:
        print(f"[{acc_id}] Error assuming role: {e}")