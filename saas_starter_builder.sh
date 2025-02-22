#!/bin/bash

# --- Helper Functions ---

# Creates a Django app and its basic structure.
create_app() {
  local app_name="$1"
  local script_dir="$(dirname "$0")"  # Get the script's directory
  local template_dir="$script_dir/saas_starter_templates/$app_name"

  # Create app directory
  echo -e "\e[32mCreating app '$app_name'...\e[0m" # Green color
  python manage.py startapp "$app_name"

  # Copy and process template files
  cp -r "$template_dir/templates" "$app_name/"
    # Create apps.py with a custom AppConfig
  if [[ "$app_name" == "admin" ]]; then
    envsubst < "$template_dir/apps.py.template" > "$app_name/apps.py"
  else
    # Capitalize the first letter of the app name
    APP_NAME_CAPITALIZED=$(echo "$app_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    envsubst < "$template_dir/apps.py.template" > "$app_name/apps.py"
  fi
  envsubst < "$template_dir/urls.py.template" > "$app_name/urls.py"
  envsubst < "$template_dir/views.py.template" > "$app_name/views.py"

  echo -e "\e[32mApp '$app_name' created.\e[0m" # Green color
}

# --- Main Script ---
# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get project information.
echo -e "${GREEN}Getting project information...${NC}"
read -p "Project name: " project_name
#read -p "App name (we'll use 'public' for the initial app, leave blank for default): " app_name #Removed app_name
read -p "Use PostgreSQL? (y/N): " use_postgres

# Set default for use_postgres if no input is provided
if [[ -z "$use_postgres" ]]; then
  use_postgres="N"
fi

if [[ "$use_postgres" == "Y" || "$use_postgres" == "y" ]]; then
    read -p "PostgreSQL admin username: " db_admin_username
    read -p "PostgreSQL admin password: " db_admin_password
    read -p "PostgreSQL admin email: " db_admin_email
fi

# Create the project directory.
echo -e "${GREEN}Creating project directory...${NC}"
mkdir "$project_name"
cd "$project_name"

# Create a virtual environment.
echo -e "${GREEN}Creating virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install Django.
echo -e "${GREEN}Installing Django...${NC}"
pip install django

# Create the Django project.
echo -e "${GREEN}Creating Django project...${NC}"
django-admin startproject core .

# --- Set default app name ---
#if [ -z "$app_name" ]; then #Removed app_name
app_name="public"
#fi

# --- Create Apps ---
echo -e "${GREEN}Creating Apps...${NC}"
create_app "$app_name"
create_app "users"
create_app "private"
create_app "admin"
create_app "common" # Create the 'common' app

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${NC}"
mkdir templates
mkdir static

# --- Set environment variables for substitution ---
echo -e "${GREEN}Setting environment variables...${NC}"
export APP_NAME="$app_name"
export PROJECT_NAME="$project_name"
if [[ "$use_postgres" == "Y" || "$use_postgres" == "y" ]]; then
  export DB_ADMIN_USERNAME="$db_admin_username"
  export DB_ADMIN_PASSWORD="$db_admin_password"
  export DB_ADMIN_EMAIL="$db_admin_email"
  export DATABASE_URL="postgres://$db_admin_username:$db_admin_password@localhost:5432/$project_name"
fi
export DJANGO_SECRET_KEY=$(openssl rand -base64 32)
export DEBUG="True"

# --- Get script directory ---
local script_dir="$(dirname "$0")"

# --- Configure core/settings.py ---
echo -e "${GREEN}Configuring core/settings.py...${NC}"
envsubst < "$script_dir/saas_starter_templates/core/settings.py.template" > core/settings.py

# --- Configure core/urls.py ---
echo -e "${GREEN}Configuring core/urls.py...${NC}"
envsubst < "$script_dir/saas_starter_templates/core/urls.py.template" > core/urls.py

# --- Create base Templates ---
echo -e "${GREEN}Creating base Templates...${NC}"
cp "$script_dir/saas_starter_templates/templates/base.html.template" templates/base.html

# --- Create a requirements.txt file. ---
echo -e "${GREEN}Creating requirements.txt...${NC}"
pip freeze > requirements.txt

# --- Create a .env file ---
echo -e "${GREEN}Creating .env file...${NC}"
envsubst < "$script_dir/saas_starter_templates/.env.template" > .env

# --- Create a basic Dockerfile ---
echo -e "${GREEN}Creating Dockerfile...${NC}"
envsubst < "$script_dir/saas_starter_templates/Dockerfile.template" > Dockerfile

# Initial project setup (database migrations, etc.).
echo -e "${GREEN}Running initial project setup...${NC}"
python manage.py migrate
if [[ "$use_postgres" == "Y" || "$use_postgres" == "y" ]]; then
  python manage.py createsuperuser --username "$db_admin_username" --email "$db_admin_email"
fi

echo -e "${GREEN}Project '$project_name' created successfully.${NC}"
echo "Remember to:"
echo "- Fill in the .env file with appropriate values."
echo "- Customize the Dockerfile as needed."
echo "- Start building your apps!"
echo "- If you want to delete the project simply run: rm -rf $project_name"
echo ""
echo "To run the development server:"
echo "1. Navigate to the project directory:  cd $project_name"
echo "2. Activate the virtual environment: source venv/bin/activate"
echo "3. Start the server: python manage.py runserver"
echo "4. Open your web browser and go to: http://127.0.0.1:8000/"
echo "5. To deactivate the virtual environment, run: deactivate"

deactivate # Deactivate virtual env
