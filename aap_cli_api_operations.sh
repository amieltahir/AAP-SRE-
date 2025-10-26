#!/bin/bash
# lab1.4_cli_api_operations_fixed.sh

echo "==============================================="
echo "AAP CLI & API Operations - Fixed Authentication"
echo "==============================================="

# Set variables
CONTROLLER_URL="https://localhost"
TOKEN_FILE="$HOME/.aap_token"
CREDENTIALS_FILE="$HOME/.aap_credentials"
COOKIE_FILE="/tmp/aap_cookies_$$.txt"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Cleanup function
cleanup() {
    rm -f "$COOKIE_FILE"
}
trap cleanup EXIT

# Function to check dependencies
check_dependencies() {
    echo -e "${YELLOW}=== Checking Dependencies ===${NC}"
    
    command -v jq >/dev/null 2>&1 || { 
        echo -e "${RED}jq not found. Installing...${NC}"
        sudo dnf install -y jq
    }
    
    echo -e "${GREEN}✓ Dependencies checked${NC}"
}

# Function to get credentials
get_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo -e "${YELLOW}Using stored credentials${NC}"
        source "$CREDENTIALS_FILE"
    else
        echo -e "${YELLOW}=== AAP Credentials Setup ===${NC}"
        echo "Please enter your AAP administrator credentials:"
        read -p "Username (default: admin): " AAP_USERNAME
        AAP_USERNAME=${AAP_USERNAME:-admin}
        read -s -p "Password: " AAP_PASSWORD
        echo
        
        # Test credentials
        if test_login; then
            read -p "Save credentials securely? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cat > "$CREDENTIALS_FILE" << EOF
AAP_USERNAME="$AAP_USERNAME"
AAP_PASSWORD="$AAP_PASSWORD"
EOF
                chmod 600 "$CREDENTIALS_FILE"
                echo -e "${GREEN}✓ Credentials saved to $CREDENTIALS_FILE${NC}"
            fi
        else
            echo -e "${RED}✗ Invalid credentials. Please try again.${NC}"
            exit 1
        fi
    fi
}

# Function to test login credentials
test_login() {
    echo -e "${YELLOW}Testing credentials...${NC}"
    
    # Get initial cookies and CSRF token
    INIT_RESPONSE=$(curl -k -s -c "$COOKIE_FILE" "$CONTROLLER_URL/api/login/")
    CSRF_TOKEN=$(echo "$INIT_RESPONSE" | grep -oP "csrfToken.:.\K[^\"]+" || echo "")
    
    if [ -z "$CSRF_TOKEN" ]; then
        # Try alternative method to get CSRF
        CSRF_TOKEN=$(curl -k -s -c "$COOKIE_FILE" "$CONTROLLER_URL" | \
            grep -oP "name=['\"]csrfmiddlewaretoken['\"] value=['\"]([^'\"]+)['\"]" | \
            sed -n 's/.*value="\([^"]*\)".*/\1/p' | head -1)
    fi
    
    if [ -z "$CSRF_TOKEN" ]; then
        echo -e "${RED}Could not retrieve CSRF token${NC}"
        return 1
    fi
    
    # Attempt login
    LOGIN_RESPONSE=$(curl -k -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
        -H "X-CSRFToken: $CSRF_TOKEN" \
        -H "Referer: $CONTROLLER_URL/api/login/" \
        -d "username=$AAP_USERNAME&password=$AAP_PASSWORD" \
        "$CONTROLLER_URL/api/login/")
    
    # Check if login was successful by testing a protected endpoint
    TEST_RESPONSE=$(curl -k -s -b "$COOKIE_FILE" -w "%{http_code}" \
        "$CONTROLLER_URL/api/v2/me/")
    HTTP_CODE="${TEST_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Login successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Login failed${NC}"
        return 1
    fi
}

# Function to create API token using session authentication
create_api_token() {
    echo -e "${YELLOW}=== Creating API Token ===${NC}"
    
    # First ensure we have a valid session
    if ! test_login; then
        echo -e "${RED}No valid session. Cannot create token.${NC}"
        return 1
    fi
    
    # Get CSRF token from cookies for the API request
    CSRF_TOKEN=$(grep 'csrftoken' "$COOKIE_FILE" | awk '{print $7}')
    
    if [ -z "$CSRF_TOKEN" ]; then
        echo -e "${RED}Could not get CSRF token from session${NC}"
        return 1
    fi
    
    echo "Using CSRF token from session"
    
    # Create the API token
    TOKEN_RESPONSE=$(curl -k -s -b "$COOKIE_FILE" \
        -H "X-CSRFToken: $CSRF_TOKEN" \
        -H "Content-Type: application/json" \
        -H "Referer: $CONTROLLER_URL" \
        -X POST \
        -d "{\"description\":\"Auto-generated token for CLI operations $(date)\", \"scope\":\"write\"}" \
        "$CONTROLLER_URL/api/v2/tokens/")
    
    # Extract token from response
    API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
    
    if [ -n "$API_TOKEN" ]; then
        echo "$API_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo -e "${GREEN}✓ API token created and saved to $TOKEN_FILE${NC}"
        echo -e "${YELLOW}Token: $API_TOKEN${NC}"
        return 0
    else
        echo -e "${RED}Failed to create API token${NC}"
        echo "Response: $TOKEN_RESPONSE"
        echo "Trying alternative method..."
        
        # Alternative method - try without CSRF
        TOKEN_RESPONSE=$(curl -k -s -b "$COOKIE_FILE" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "{\"description\":\"Auto-generated token for CLI operations $(date)\", \"scope\":\"write\"}" \
            "$CONTROLLER_URL/api/v2/tokens/")
        
        API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
        if [ -n "$API_TOKEN" ]; then
            echo "$API_TOKEN" > "$TOKEN_FILE"
            chmod 600 "$TOKEN_FILE"
            echo -e "${GREEN}✓ API token created (alternative method)${NC}"
            return 0
        fi
        
        return 1
    fi
}

# Function to get API token
get_api_token() {
    if [ -f "$TOKEN_FILE" ]; then
        API_TOKEN=$(cat "$TOKEN_FILE")
        echo -e "${YELLOW}Using existing API token${NC}"
        
        # Test if token is still valid
        if test_api_connectivity; then
            return 0
        else
            echo -e "${YELLOW}Token expired or invalid. Creating new one...${NC}"
            create_api_token
        fi
    else
        echo -e "${YELLOW}No API token found. Creating new one...${NC}"
        create_api_token
    fi
    
    # Load the new token
    if [ -f "$TOKEN_FILE" ]; then
        API_TOKEN=$(cat "$TOKEN_FILE")
        return 0
    else
        echo -e "${RED}Failed to create or retrieve API token${NC}"
        return 1
    fi
}

# Function to test API connectivity
test_api_connectivity() {
    echo -e "${YELLOW}Testing API connectivity...${NC}"
    response=$(curl -k -s -w "%{http_code}" -H "Authorization: Bearer $API_TOKEN" \
        "$CONTROLLER_URL/api/v2/ping/")
    http_code=${response: -3}
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ API connectivity: SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}✗ API connectivity: FAILED (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to get user information
get_user_info() {
    echo -e "${YELLOW}=== User Information ===${NC}"
    USER_INFO=$(curl -k -s -H "Authorization: Bearer $API_TOKEN" \
        "$CONTROLLER_URL/api/v2/me/")
    
    if [ $? -eq 0 ]; then
        echo "Username: $(echo "$USER_INFO" | jq -r '.username')"
        echo "Email: $(echo "$USER_INFO" | jq -r '.email // "Not set"')"
        echo "Superuser: $(echo "$USER_INFO" | jq -r '.is_superuser')"
    else
        echo -e "${RED}Failed to get user information${NC}"
    fi
}

# Function to get platform information
get_platform_info() {
    echo -e "${YELLOW}=== Platform Information ===${NC}"
    PLATFORM_INFO=$(curl -k -s -H "Authorization: Bearer $API_TOKEN" \
        "$CONTROLLER_URL/api/v2/config/")
    
    if [ $? -eq 0 ]; then
        echo "$PLATFORM_INFO" | jq '{
            version: .version,
            install_uuid: .install_uuid,
            time_zone: .time_zone,
            license_type: .license_type,
            project_base_dir: .project_base_dir
        }'
    else
        echo -e "${RED}Failed to get platform information${NC}"
    fi
}

# Function to list resources
list_resources() {
    echo -e "${YELLOW}=== Resource Overview ===${NC}"
    
    declare -A resources=(
        ["organizations"]="Organizations"
        ["inventories"]="Inventories"
        ["projects"]="Projects"
        ["job_templates"]="Job Templates"
        ["credentials"]="Credentials"
    )
    
    for endpoint in "${!resources[@]}"; do
        response=$(curl -k -s -H "Authorization: Bearer $API_TOKEN" \
            "$CONTROLLER_URL/api/v2/${endpoint}/")
        count=$(echo "$response" | jq '.count // 0')
        echo "${resources[$endpoint]}: $count"
    done
}

# Simplified job template operations
job_template_operations() {
    echo -e "${YELLOW}=== Job Templates ===${NC}"
    
    response=$(curl -k -s -H "Authorization: Bearer $API_TOKEN" \
        "$CONTROLLER_URL/api/v2/job_templates/?page_size=5")
    
    if echo "$response" | jq -e '.results' > /dev/null; then
        echo "$response" | jq -r '.results[] | "\(.id): \(.name)"'
        
        # Get first job template ID
        JT_ID=$(echo "$response" | jq -r '.results[0].id // empty')
        
        if [ -n "$JT_ID" ]; then
            read -p "Launch first job template ($JT_ID)? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                launch_job "$JT_ID"
            fi
        fi
    else
        echo -e "${RED}Failed to fetch job templates${NC}"
    fi
}

# Function to launch job
launch_job() {
    local jt_id=$1
    echo -e "${YELLOW}Launching Job Template $jt_id${NC}"
    
    launch_response=$(curl -k -s -X POST \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        "$CONTROLLER_URL/api/v2/job_templates/$jt_id/launch/")
    
    job_id=$(echo "$launch_response" | jq -r '.id // empty')
    
    if [ -n "$job_id" ]; then
        echo -e "${GREEN}✓ Job launched successfully! Job ID: $job_id${NC}"
        monitor_job "$job_id"
    else
        echo -e "${RED}✗ Failed to launch job${NC}"
    fi
}

# Function to monitor job
monitor_job() {
    local job_id=$1
    echo -e "${YELLOW}Monitoring Job $job_id${NC}"
    
    for i in {1..10}; do
        job_info=$(curl -k -s -H "Authorization: Bearer $API_TOKEN" \
            "$CONTROLLER_URL/api/v2/jobs/$job_id/")
        
        status=$(echo "$job_info" | jq -r '.status')
        name=$(echo "$job_info" | jq -r '.name')
        
        echo "Poll $i: $name - Status: $status"
        
        if [[ "$status" =~ ^(successful|failed|canceled)$ ]]; then
            echo -e "${GREEN}Job completed: $status${NC}"
            break
        fi
        sleep 5
    done
}

# Manual token creation fallback
manual_token_creation() {
    echo -e "${YELLOW}=== Manual Token Creation Required ===${NC}"
    echo "Automatic token creation failed. Please create a token manually:"
    echo "1. Open your browser and go to: $CONTROLLER_URL"
    echo "2. Log in with your credentials"
    echo "3. Click on your username in the top right"
    echo "4. Select 'Tokens' from the dropdown"
    echo "5. Click 'Add' to create a new token"
    echo "6. Copy the token value and paste it below"
    echo ""
    read -p "Enter your API token: " MANUAL_TOKEN
    
    if [ -n "$MANUAL_TOKEN" ]; then
        echo "$MANUAL_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo -e "${GREEN}✓ Token saved to $TOKEN_FILE${NC}"
        API_TOKEN="$MANUAL_TOKEN"
        return 0
    else
        echo -e "${RED}No token provided${NC}"
        return 1
    fi
}

# Main execution
main() {
    check_dependencies
    get_credentials
    
    # Try automated token creation first
    if create_api_token; then
        echo -e "${GREEN}✓ Token created successfully${NC}"
    else
        echo -e "${YELLOW}Automated token creation failed. Trying manual method...${NC}"
        manual_token_creation
    fi
    
    # Now test with the token
    if get_api_token && test_api_connectivity; then
        echo -e "${GREEN}✓ Ready to use AAP API${NC}"
        get_user_info
        get_platform_info
        list_resources
        
        # Simple menu
        while true; do
            echo -e "\n${YELLOW}=== AAP API Operations ===${NC}"
            echo "1) Job Template Operations"
            echo "2) Test API"
            echo "3) Exit"
            
            read -p "Select operation (1-3): " choice
            
            case $choice in
                1) job_template_operations ;;
                2) test_api_connectivity ;;
                3) 
                    echo -e "${GREEN}Exiting...${NC}"
                    exit 0
                    ;;
                *) echo -e "${RED}Invalid choice${NC}" ;;
            esac
        done
    else
        echo -e "${RED}Failed to establish API connection${NC}"
        exit 1
    fi
}

# Run main function
main
