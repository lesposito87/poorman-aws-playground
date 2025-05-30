#!/bin/bash

# Container image to use
IMAGE="lesposito87/poorman-aws-playground:latest"
CONTAINER_NAME="poorman-aws-playground"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a container runtime is operational
is_running() {
    if "$1" ps >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Print banner
echo "=============================="
echo "=== Poorman-AWS-Playground ==="
echo "=============================="
echo

# Check for Podman or Docker
if command_exists podman && is_running podman; then
    echo "[🚀 PREFLIGHT CHECKS 🚀] Podman is installed & running ✅"
    echo
    CONTAINER_CMD="podman"
elif command_exists docker && is_running docker; then
    echo "[🚀 PREFLIGHT CHECKS 🚀] Docker is installed & running ✅"
    echo
    CONTAINER_CMD="docker"
else
    echo "[🚀 PREFLIGHT CHECKS 🚀] Neither Podman nor Docker is installed or running ❌"
    echo
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract values using awk (compatible with macOS & Linux)
extract_var() {
    awk -v var="$1" '
    $1 == "variable" && $2 == "\"" var "\"" { found = 1; next }
    found && /default/ {
        gsub(/default[[:space:]]*=[[:space:]]*\"/, "", $0)
        gsub(/\".*/, "", $0)
        print $0
        exit
    }' "$TERRAGRUNT_FILE" | tr -d '[:space:]'  # Trim spaces
}

# Function to check if a file exists
check_file_exists() {
    local file="$1"
    if [[ -z "$file" ]]; then
        echo "[ERROR] Variable for a required file is empty! ❌"
        exit 1
    fi
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] Required file not found: $file ❌"
        exit 1
    fi
}

# Function to check if a directory exists and ends with a trailing slash
check_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "[ERROR] Directory not found: $dir ❌"
        exit 1
    fi
    if [[ "${dir: -1}" != "/" ]]; then
        echo "[ERROR] Directory must end with a trailing slash: $dir ❌"
        exit 1
    fi
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "[ERROR] Invalid email address: $email ❌"
        exit 1
    fi
}

# Function to replace placeholders in root.hcl
replace_placeholders() {
    local AWS_ACCOUNT_NAME="$1"
    local AWS_CREDENTIALS_FILE="$2"
    local AWS_EMAIL_ADDRESS="$3"
    local AWS_KEY_PAIR_PRIVATE="$4"
    local AWS_KEY_PAIR_PUBLIC="$5"
    local AWS_REGION="$6"
    local AWS_ROUTE53_PRIVATE_ZONE="$7"
    local AWS_S3_BUCKET="$8"
    local ANSIBLE_OPENVPN_CLIENT_DIR="$9"
    
    # Validate email address format
    validate_email "$AWS_EMAIL_ADDRESS"
    
    # Check if required files exist
    check_file_exists "$AWS_KEY_PAIR_PRIVATE"
    check_file_exists "$AWS_KEY_PAIR_PUBLIC"
    check_file_exists "$AWS_CREDENTIALS_FILE"
    
    # Check if directory exists and ends with trailing slash
    check_directory "$ANSIBLE_OPENVPN_CLIENT_DIR"
    
    # Backup root.hcl if it exists
    BACKUP_FILE="$SCRIPT_DIR/root.hcl"
    if [[ -f "$BACKUP_FILE" ]]; then
        DATE=$(date +%Y%m%d)
        COUNTER=001
        BACKUP_FILE="$SCRIPT_DIR/root.hcl.$DATE.$COUNTER"
        while [[ -f "$BACKUP_FILE" ]]; do
            COUNTER=$(printf "%03d" $((10#$COUNTER + 1)))
            BACKUP_FILE="$SCRIPT_DIR/root.hcl.$DATE.$COUNTER"
        done
        cp "$SCRIPT_DIR/root.hcl" "$BACKUP_FILE"
        echo
        echo "[INFO] Existing root.hcl file backed up as $BACKUP_FILE"
    fi
    
    # Create new root.hcl with replaced values
    TERRAGRUNT_INIT_FILE="$SCRIPT_DIR/root.hcl.init"
    cp "$TERRAGRUNT_INIT_FILE" "$SCRIPT_DIR/root.hcl"

    # Use sed to replace placeholders
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -e "s|__PLACEHOLDER_aws_account_name__|$AWS_ACCOUNT_NAME|g" \
                  -e "s|__PLACEHOLDER_aws_email_address__|$AWS_EMAIL_ADDRESS|g" \
                  -e "s|__PLACEHOLDER_aws_key_pair_private__|$AWS_KEY_PAIR_PRIVATE|g" \
                  -e "s|__PLACEHOLDER_aws_key_pair_public__|$AWS_KEY_PAIR_PUBLIC|g" \
                  -e "s|__PLACEHOLDER_aws_region__|$AWS_REGION|g" \
                  -e "s|__PLACEHOLDER_aws_route53_private_zone__|$AWS_ROUTE53_PRIVATE_ZONE|g" \
                  -e "s|__PLACEHOLDER_aws_s3_bucket__|$AWS_S3_BUCKET|g" \
                  -e "s|__PLACEHOLDER_aws_shared_credentials_files__|$AWS_CREDENTIALS_FILE|g" \
                  -e "s|__PLACEHOLDER_openvpn_client_dir__|$ANSIBLE_OPENVPN_CLIENT_DIR|g" \
                  "$SCRIPT_DIR/root.hcl"
    else
        sed -i -e "s|__PLACEHOLDER_aws_account_name__|$AWS_ACCOUNT_NAME|g" \
               -e "s|__PLACEHOLDER_aws_email_address__|$AWS_EMAIL_ADDRESS|g" \
               -e "s|__PLACEHOLDER_aws_key_pair_private__|$AWS_KEY_PAIR_PRIVATE|g" \
               -e "s|__PLACEHOLDER_aws_key_pair_public__|$AWS_KEY_PAIR_PUBLIC|g" \
               -e "s|__PLACEHOLDER_aws_region__|$AWS_REGION|g" \
               -e "s|__PLACEHOLDER_aws_route53_private_zone__|$AWS_ROUTE53_PRIVATE_ZONE|g" \
               -e "s|__PLACEHOLDER_aws_s3_bucket__|$AWS_S3_BUCKET|g" \
               -e "s|__PLACEHOLDER_aws_shared_credentials_files__|$AWS_CREDENTIALS_FILE|g" \
               -e "s|__PLACEHOLDER_openvpn_client_dir__|$ANSIBLE_OPENVPN_CLIENT_DIR|g" \
               "$SCRIPT_DIR/root.hcl"
    fi

    echo "[INFO] Placeholders replaced successfully. New root.hcl file created."

    # Check if poorman-aws-playground exists and rename it
    if [[ -d "$SCRIPT_DIR/poorman-aws-playground" ]]; then
        echo "[INFO] Renaming 'poorman-aws-playground' directory to '$AWS_ACCOUNT_NAME'..."
        echo
        mv "$SCRIPT_DIR/poorman-aws-playground" "$SCRIPT_DIR/$AWS_ACCOUNT_NAME"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to rename directory 'poorman-aws-playground' to '$AWS_ACCOUNT_NAME'. Exiting... ❌"
            exit 1
        fi
        echo "[INFO] Directory renamed successfully ✅"
        echo
    # Check if AWS_ACCOUNT_NAME directory exists
    elif [[ -d "$SCRIPT_DIR/$AWS_ACCOUNT_NAME" ]]; then
        echo "[INFO] '$AWS_ACCOUNT_NAME' directory already exists."
        echo
    else
        echo "[ERROR] Neither 'poorman-aws-playground' nor '$AWS_ACCOUNT_NAME' directory exists. Exiting... ❌"
        echo
        exit 1
    fi

    # Check if AWS credentials have rw access to the S3 bucket
    echo "[INFO] Validating AWS Credentials checking S3 access..."
    echo
    # Test write access by attempting to upload a test file
    TEST_FILE="test-s3-access.txt"
    echo "dummy entry" > "$TEST_FILE"

    AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDENTIALS_FILE" aws s3 cp "$TEST_FILE" "s3://$AWS_S3_BUCKET/$TEST_FILE" --region "$AWS_REGION"
    if [[ $? -eq 0 ]]; then
        echo "[INFO] Write access to the S3 bucket is successful ✅"
        echo
    else
        echo "[ERROR] Failed to write to the S3 bucket. Please check your permissions ❌"
        rm -f "$TEST_FILE"
        exit 1
    fi

    # Test read access by attempting to download the test file
    AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDENTIALS_FILE" aws s3 cp "s3://$AWS_S3_BUCKET/$TEST_FILE" "$TEST_FILE" --region "$AWS_REGION"
    if [[ $? -eq 0 ]]; then
        echo "[INFO] Read access to the S3 bucket is successful ✅"
        echo
    else
        echo "[ERROR] Failed to read from the S3 bucket. Please check your permissions ❌"
        rm -f "$TEST_FILE"
        exit 1
    fi

    # Remove the test file from the S3 bucket after the tests
    AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDENTIALS_FILE" aws s3 rm "s3://$AWS_S3_BUCKET/$TEST_FILE" --region "$AWS_REGION"
    if [[ $? -eq 0 ]]; then
        echo "[INFO] Test file successfully removed from S3 ✅"
        echo
    else
        echo "[ERROR] Failed to remove the test file from S3 ❌"
        rm -f "$TEST_FILE"
        exit 1
    fi

    # Clean up the test file
    rm -f "$TEST_FILE"
}

# Check if root.hcl.init exists
TERRAGRUNT_FILE="$SCRIPT_DIR/root.hcl"
if [[ ! -f "$TERRAGRUNT_FILE" ]]; then
    echo "[WARNING] 'root.hcl' not found in script directory! Please provide the following info to create all the required files:"
    # Ask interactively for placeholder values
    read -rp "➜ Enter your AWS account name (e.g., 'myaccount-root'): " AWS_ACCOUNT_NAME
    read -rp "➜ Enter the absolute path to your AWS Credentials File (e.g., '/Users/myuser/.aws/credentials'): " AWS_CREDENTIALS_FILE
    read -rp "➜ Enter a valid email address (e.g., 'user@domain.com'): " AWS_EMAIL_ADDRESS
    read -rp "➜ Enter the absolute path to your AWS key pair SSH private key (e.g., '/Users/myuser/.ssh/id_rsa'): " AWS_KEY_PAIR_PRIVATE
    read -rp "➜ Enter the absolute path to your AWS key pair SSH public key (e.g., '/Users/myuser/.ssh/id_rsa.pub'): " AWS_KEY_PAIR_PUBLIC
    read -rp "➜ Enter your AWS region (e.g., 'eu-south-1'): " AWS_REGION
    read -rp "➜ Enter your AWS Route53 private zone (e.g., 'myaccount.intra'): " AWS_ROUTE53_PRIVATE_ZONE
    read -rp "➜ Enter your AWS S3 bucket name: " AWS_S3_BUCKET
    read -rp "➜ Enter the absolute path to your OpenVPN client directory (this MUST ends with '/' => e.g., '/Users/myuser/openvpn/'): " ANSIBLE_OPENVPN_CLIENT_DIR
    
    # Call function to replace placeholders
    replace_placeholders "$AWS_ACCOUNT_NAME" "$AWS_CREDENTIALS_FILE" "$AWS_EMAIL_ADDRESS" "$AWS_KEY_PAIR_PRIVATE" "$AWS_KEY_PAIR_PUBLIC" "$AWS_REGION" "$AWS_ROUTE53_PRIVATE_ZONE" "$AWS_S3_BUCKET" "$ANSIBLE_OPENVPN_CLIENT_DIR"
    exit 0
fi

# Interactive menu
echo "1) Generate Poorman-AWS-Playground's container run command"
echo "2) Initialize and set up Poorman-AWS-Playground"
read -rp "Enter choice (1 or 2): " choice
echo
case "$choice" in
    1)
        # Extract variables
        AWS_CREDENTIALS_FILE=$(extract_var "aws_shared_credentials_file")
        AWS_KEY_PAIR_PRIVATE=$(extract_var "aws_key_pair_private")
        AWS_KEY_PAIR_PUBLIC=$(extract_var "aws_key_pair_public")
        ANSIBLE_OPENVPN_CLIENT_DIR=$(extract_var "ansible_openvpn_client_dir")
        AWS_EMAIL_ADDRESS=$(extract_var "aws_email_address")
        AWS_REGION=$(extract_var "aws_region")
        AWS_ROUTE53_PRIVATE_ZONE=$(extract_var "aws_route53_private_zone")
        AWS_S3_BUCKET=$(extract_var "aws_s3_bucket")
        AWS_ACCOUNT_NAME=$(extract_var "account_name")    

        # Check if directory with account name exists
        if [[ ! -d "$SCRIPT_DIR/$AWS_ACCOUNT_NAME" ]]; then
            echo "[ERROR] No directory found with the name '$AWS_ACCOUNT_NAME' ❌"
            echo "[INFO] Please run the 'poorman-aws-playground-init.sh' script to create all the necessary files and directories."
            exit 1
        fi

        # Generate container run command
        echo "[INFO] Generating container run command..."
        
        # Construct the container run command
        RUN_COMMAND="$CONTAINER_CMD run -it -d --name $CONTAINER_NAME "
        
        # Mount necessary volumes
        RUN_COMMAND+="-v $AWS_CREDENTIALS_FILE:$AWS_CREDENTIALS_FILE "
        RUN_COMMAND+="-v $AWS_KEY_PAIR_PRIVATE:$AWS_KEY_PAIR_PRIVATE "
        RUN_COMMAND+="-v $AWS_KEY_PAIR_PUBLIC:$AWS_KEY_PAIR_PUBLIC "
        RUN_COMMAND+="-v $ANSIBLE_OPENVPN_CLIENT_DIR:$ANSIBLE_OPENVPN_CLIENT_DIR "
        RUN_COMMAND+="-v $SCRIPT_DIR:/poorman-aws-playground "
        RUN_COMMAND+="$IMAGE"

        # Output run command and exec command
        echo "---"
        echo "➜ podman pull $IMAGE"
        echo
        echo "➜ $RUN_COMMAND"
        echo
        echo "➜ $CONTAINER_CMD exec -it $CONTAINER_NAME /bin/bash"
        echo "---"
        echo
        
        # Check if container already exists with the specified name
        existing_container_details="$($CONTAINER_CMD ps -a --format "{{.Names}} {{.ID}} {{.Status}}" | grep -E "^$CONTAINER_NAME[[:space:]]+")"
        
        if [[ -n "$existing_container_details" ]]; then
            echo "[WARNING] Container '$CONTAINER_NAME' already exists ⚠️"
            echo "---"
            echo "$existing_container_details"
            echo "---"
        fi
        ;;
    2)
        # Ask interactively for placeholder values
        read -rp "➜ Enter your AWS account name (e.g., 'myaccount-root'): " AWS_ACCOUNT_NAME
        read -rp "➜ Enter the absolute path to your AWS Credentials File (e.g., '/Users/myuser/.aws/credentials'): " AWS_CREDENTIALS_FILE
        read -rp "➜ Enter a valid email address (e.g., 'user@domain.com'): " AWS_EMAIL_ADDRESS
        read -rp "➜ Enter the absolute path to your AWS key pair SSH private key (e.g., '/Users/myuser/.ssh/id_rsa'): " AWS_KEY_PAIR_PRIVATE
        read -rp "➜ Enter the absolute path to your AWS key pair SSH public key (e.g., '/Users/myuser/.ssh/id_rsa.pub'): " AWS_KEY_PAIR_PUBLIC
        read -rp "➜ Enter your AWS region (e.g., 'eu-south-1'): " AWS_REGION
        read -rp "➜ Enter your AWS Route53 private zone (e.g., 'myaccount.intra'): " AWS_ROUTE53_PRIVATE_ZONE
        read -rp "➜ Enter your AWS S3 bucket name: " AWS_S3_BUCKET
        read -rp "➜ Enter the absolute path to your OpenVPN client directory (this MUST ends with '/' => e.g., '/Users/myuser/openvpn/'): " ANSIBLE_OPENVPN_CLIENT_DIR
        
        # Call function to replace placeholders
        replace_placeholders "$AWS_ACCOUNT_NAME" "$AWS_CREDENTIALS_FILE" "$AWS_EMAIL_ADDRESS" "$AWS_KEY_PAIR_PRIVATE" "$AWS_KEY_PAIR_PUBLIC" "$AWS_REGION" "$AWS_ROUTE53_PRIVATE_ZONE" "$AWS_S3_BUCKET" "$ANSIBLE_OPENVPN_CLIENT_DIR"
        ;;
    *)
        echo "[ERROR] Invalid choice. Please enter 1 or 2 ❌"
        exit 1
        ;;
esac
