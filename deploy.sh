#!/bin/bash

set -e

# Variables
SERVICE_NAME="magical-auth-starter"
REGION="europe-southwest1"

BASH_BLUE='\033[0;34m'
BASH_NC='\033[0m'
BASH_BOLD_WHITE='\033[1;37m'
BASH_WHITE='\033[0;37m'
BASH_RED='\033[0;31m'

echo -e "
     ${BASH_BLUE}██████████    
   ██████████████  
 ██████${BASH_BOLD_WHITE}████████${BASH_BLUE}████ 
██████${BASH_BOLD_WHITE}███${BASH_BLUE}██${BASH_BOLD_WHITE}███${BASH_BLUE}██████${BASH_BOLD_WHITE}   Glide Deployment Script
${BASH_BLUE}█████${BASH_BOLD_WHITE}███${BASH_BLUE}████${BASH_BOLD_WHITE}██${BASH_BLUE}██████${BASH_WHITE}   -------------------------
${BASH_BLUE}██████${BASH_BOLD_WHITE}███${BASH_BLUE}██${BASH_BOLD_WHITE}███${BASH_BLUE}██████${BASH_NC}   Magicical Auth Demo
${BASH_BLUE}███████${BASH_BOLD_WHITE}██████${BASH_BLUE}███████
${BASH_BLUE}████████████████████${BASH_NC}   Made with ${BASH_RED}❤️${BASH_NC} by ${BASH_BOLD_WHITE}Glide
${BASH_BLUE} █████${BASH_BOLD_WHITE}████████${BASH_BLUE}█████       https://glideapi.com
${BASH_BLUE}   ██████████████
${BASH_BLUE}     ██████████${BASH_WHITE}      
                                       
"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

DARWIN_AMD_GCLOUD="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz"
DARWIN_X86_GCLOUD="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-x86_64.tar.gz"

# Check if gcloud is installed
if ! command_exists gcloud; then
    platform=$(uname -a)
    if [[ $platform == *"Linux"* ]]; then
        echo "Error: gcloud is not installed. Please install it by running 'sudo apt-get install google-cloud-sdk'."
    elif [[ $platform == *"Darwin"* ]]; then
        echo "Would you like to download gcloud for Mac? (Y/n)"
        read -r download_response
        if [ -z "$download_response" ] || [[ $download_response =~ ^[Yy]$ ]]; then
            if [[ $platform == *"arm"* ]]; then
                echo "Downloading gcloud for Apple Silicon..."
                curl -O $DARWIN_AMD_GCLOUD
                tar -xvf google-cloud-cli-darwin-arm.tar.gz ~/google-cloud-sdk
            else
                echo "Downloading gcloud for Intel Mac..."
                curl -O $DARWIN_X86_GCLOUD
                tar -xvf google-cloud-cli-darwin-x86_64.tar.gz ~/google-cloud-sdk
            fi
            echo "Installing gcloud..."
            ~/google-cloud-sdk/install.sh
            export PATH=$PATH:~/google-cloud-sdk/bin
            echo "gcloud installed successfully!"
        else
            echo "Error: gcloud is not installed. Please install it from https://cloud.google.com/sdk/docs/install."
        fi
    else
        echo "Error: gcloud is not installed. Please install it from https://cloud.google.com/sdk/docs/install."
    fi
fi

# Check if the user is logged in
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q '@'; then
    echo "You are not logged into gcloud would you like to login? (Y/n)"
    read -r login_response
    if [ -z "$login_response" ] || [[ $login_response =~ ^[Yy]$ ]]; then
        gcloud auth login
    else
        echo "Please login to gcloud and try again."
        exit 1
    fi
fi

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Using GCP Project ID: $PROJECT_ID"

if [ -z "$PROJECT_ID" ]; then
    echo "Default project not found. Which project would you like to use?"
    `gcloud projects list`
    printf "Enter Project ID: "
    read -r PROJECT_ID
    allowed_projects=$(gcloud projects list --format="value(projectId)")
    while ! echo "$allowed_projects" | grep -q "$PROJECT_ID"; do
        echo "Error: Project ID not found. Please enter a valid Project ID."
        printf "Enter Project ID: "
        read -r PROJECT_ID
    done
fi

approved_services=$(gcloud services list --enabled)
has_cloud_run=$(echo "$approved_services" | grep -q 'run.googleapis.com')
has_cloud_build=$(echo "$approved_services" | grep -q 'cloudbuild.googleapis.com')

if ! $has_cloud_build || ! $has_cloud_run; then
    $missing_services=""
    if ! $has_cloud_run; then
        missing_services+="Cloud Run"
    fi
    if ! $has_cloud_build; then
        if [ -z "$missing_services" ]; then
            missing_services+="Cloud Build"
        else
            missing_services+="and Cloud Build"
        fi
    fi
    missing_services+="APIs are required for this script. Do you want to enable them? (Y/n)"
    read -r enable_response
    if [ -z "$enable_response" ] || [[ $enable_response =~ ^[Yy]$ ]]; then
        if ! $has_cloud_run; then
            echo "Enabling Cloud Run API..."
            gcloud services enable run.googleapis.com
        fi
        if ! $has_cloud_build; then
            echo "Enabling Cloud Build API..."
            gcloud services enable cloudbuild.googleapis.com
        fi
    else
        echo "Cloud Run is required for this script. Please enable it and try again."
        exit 1
    fi
fi

# Function to parse credentials
parse_credentials() {
    # Check if .env file exists
    if [ -f .env ]; then
        echo "Found .env file. Parsing credentials..."
        source .env
        CLIENT_ID="${CLIENT_ID:-$GLIDE_CLIENT_ID}"
        CLIENT_SECRET="${CLIENT_SECRET:-$GLIDE_CLIENT_SECRET}"
    else
        echo "No .env file found. Please enter your credentials."
        echo "You can enter a JSON object, or just the Client ID."
        echo "Example JSON: {\"clientId\": \"your_id\", \"clientSecret\": \"your_secret\"}"
        echo "Or simply enter your Client ID, and you'll be prompted for the Client Secret separately."
        input=""
        sawClientID=false
        sawClientSecret=false
        sawLine=false
        sawJSON=false
        while IFS= read -r line; do
            # Check if the line is empty
            if [ -z "$line" ]; then
                if ! $sawLine; then
                    echo "Error: Client ID is required. Please enter your Client ID."
                else
                    break
                fi
            else
                sawLine=true
                if [[ $line == *CLIENT_ID=* ]] || [[ $line == *clientId* ]]; then
                    sawClientID=true
                fi
                if [[ $line == *CLIENT_SECRET=* ]] || [[ $line == *clientSecret=* ]]; then
                    sawClientSecret=true
                fi

                if [[ $line =~ "{" ]] ; then
                    sawJSON=true
                fi
                # Append non-empty line to input
                input+="$line\n"

                if $sawClientID && $sawClientSecret; then
                    break
                fi
                if ! $sawClientID && ! $sawJSON; then
                    break
                fi
                if $sawJSON && [[ $line =~ "}" ]]; then
                    break
                fi
            fi
        done

        # Remove the last newline character
        # input=${input%$'\n'}
        # echo -e $input

        # Use Python to parse the input
        credentials=$(echo $input | python3 -c "
import sys, json
input_str = sys.stdin.read().strip()
try:
    # Try parsing as JSON
    str_without_newline = input_str.replace('\\\n', '')
    string_as_bytes_array = bytearray(str_without_newline, 'utf-8')
    data = json.loads(str_without_newline)
    
    print(f'GLIDE_CLIENT_ID={data.get(\"clientId\", \"\")}')
    print(f'GLIDE_CLIENT_SECRET={data.get(\"clientSecret\", \"\")}')
except json.JSONDecodeError:
    # If not JSON, try .env format
    if '=' in input_str:
        for line in input_str.split('\n'):
            if line.strip():
                key, value = line.split('=', 1)
                print(f'{key.strip()}={value.strip()}')
    else:
        # Assume it's just the client ID
        print(f'GLIDE_CLIENT_ID={input_str}')
        print('GLIDE_CLIENT_SECRET=')
")

lines=$(echo -e $credentials)

        # Parse the Python output
        for line in $lines; do
            if [[ $line == GLIDE_CLIENT_ID=* ]]; then
                CLIENT_ID="${line#GLIDE_CLIENT_ID=}"
            elif [[ $line == GLIDE_CLIENT_SECRET=* ]]; then
                CLIENT_SECRET="${line#GLIDE_CLIENT_SECRET=}"
            fi
        done

        # If CLIENT_SECRET is empty, prompt for it
        if [ -z "$CLIENT_SECRET" ]; then
            echo "Enter your Client Secret:"
            read -r CLIENT_SECRET
        fi
    fi
}

# Function to check if app is already deployed
check_existing_deployment() {
    if gcloud run services describe $SERVICE_NAME --region $REGION >/dev/null 2>&1; then
        return 0  # App exists
    else
        return 1  # App doesn't exist
    fi
}

# Function to deploy the app
deploy_app() {
    echo "Building your CloudRun application..."
    $attempt = 0
    gcloud builds submit --tag gcr.io/${PROJECT_ID}/${SERVICE_NAME} .;
    
    res=$?
    while [ $res -ne 0 ]; do
        if [ $attempt -eq 10 ]; then
            echo "Failed to build the application. Please check your configuration and try again."
            return 1
        fi
        echo "Build failed. Retrying..."
        gcloud builds submit --tag gcr.io/${PROJECT_ID}/${SERVICE_NAME} .
        res=$?
        attempt=$((attempt + 1))
    done

    echo "Deploying your CloudRun application..."
    if gcloud run deploy $SERVICE_NAME --image gcr.io/${PROJECT_ID}/${SERVICE_NAME} --region $REGION --env-vars-file=appsecrets.yaml --allow-unauthenticated; then
        echo "Deployment successful!"
        return 0
    else
        echo "Deployment failed. Please check your app configuration and try again."
        return 1
    fi
}

# Function to get and print the default domain
get_and_print_domain() {
    echo "Getting the default domain..."
    DOMAIN=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)")

    appSecrets=$(cat appsecrets.yaml)
    if [[ $appSecrets == *"MAGIC_REDIRECT_URI"* ]]; then
        print_finished_message $DOMAIN
        return 0
    fi

    echo "Updating appsecrets.yaml with the redirect URI..."
    echo -e "\nMAGIC_REDIRECT_URI: $DOMAIN" >> appsecrets.yaml
    echo "Your appsecrets.yaml file has been updated with the redirect URI."

    echo "Setting the redirect URI environment variable..."
    gcloud run services update $SERVICE_NAME --region $REGION --update-env-vars=MAGIC_REDIRECT_URI=$DOMAIN
    print_finished_message $DOMAIN
}

print_finished_message() {
    local domain=$1
    echo -e "
${BASH_BLUE}Deployment complete!${BASH_NC}
Your app is now live at ${BASH_BOLD_WHITE}$domain${BASH_NC}"
}

# Main execution
parse_credentials

if ! [ -f .env ]; then
    echo "Creating .env file..."
    echo "GLIDE_CLIENT_ID=$CLIENT_ID" > .env
    echo "GLIDE_CLIENT_SECRET=$CLIENT_SECRET" >> .env
fi

if ! [ -f appsecrets.yaml ]; then
    echo "Creating appsecrets.yaml file..."
    echo "GLIDE_CLIENT_ID: $CLIENT_ID" > appsecrets.yaml
    echo "GLIDE_CLIENT_SECRET: $CLIENT_SECRET" >> appsecrets.yaml
fi

if check_existing_deployment; then
    echo "Deployment found"
    echo "Do you want to update your existing deployment? (Y/n)"
    read -r update_response
    if [ -z "$update_response" ] || [[ $update_response =~ ^[Yy]$ ]]; then
        if deploy_app; then
            get_and_print_domain
        fi
    else
        echo "Skipping update. Retrieving existing domain..."
        get_and_print_domain
    fi
else
    echo "No existing deployment found."
    echo "Do you want to deploy your application to cloud run? (Y/n)"
    read -r deploy_response
    if [ -z "$deploy_response" ] || [[ $deploy_response =~ ^[Yy]$ ]]; then
        if deploy_app; then
            get_and_print_domain
        fi
    else
        echo "Skipping deployment. Exiting..."
    fi
fi