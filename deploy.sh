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

# Check if gcloud is installed
if ! command_exists gcloud; then
    echo "Error: gcloud is not installed. Please install the Google Cloud SDK."
    echo "    You can download it from: https://cloud.google.com/sdk/"
    exit 1
fi

# Check if the user is logged in
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q '@'; then
    echo "Error: You are not logged in to gcloud. Please run 'gcloud auth login' first."
    exit 1
fi

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Using GCP Project ID: $PROJECT_ID"

if [ -z "$PROJECT_ID" ]; then
    echo "Error: No project ID found. Please run 'gcloud config set project YOUR_PROJECT_ID' first."
    exit 1
fi

# Check if App Engine is enabled
if ! gcloud services list --enabled | grep -q 'run.googleapis.com'; then
    echo "Error: App Engine is not enabled for this project. Please enable it in the Google Cloud Console."
    echo "You can enable it by visiting: https://console.cloud.google.com/apis/library/run.googleapis.com?project=$PROJECT_ID"
    exit 1
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
    gcloud builds submit --tag gcr.io/${PROJECT_ID}/${SERVICE_NAME}
    
    res=$?
    if [ $res -ne 0 ]; then
        echo "Build failed. Please check your app configuration and try again."
        return 1
    fi

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
    echo "Do you want to update your existing deployment? (y/n)"
    read -r update_response
    if [[ $update_response =~ ^[Yy]$ ]]; then
        if deploy_app; then
            get_and_print_domain
        fi
    else
        echo "Skipping update. Retrieving existing domain..."
        get_and_print_domain
    fi
else
    echo "No existing deployment found."
    echo "Do you want to deploy your application to cloud run? (y/n)"
    read -r deploy_response
    if [[ $deploy_response =~ ^[Yy]$ ]]; then
        if deploy_app; then
            get_and_print_domain
        fi
    else
        echo "Skipping deployment. Exiting..."
    fi
fi


