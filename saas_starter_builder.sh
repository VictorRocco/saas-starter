#!/bin/bash

# --- Helper Functions ---

# Creates a Django app and its basic structure.
create_app() {
  local app_name="$1"
  local script_dir="$(dirname "$0")"  # Get the script's directory
  local template_dir="$script_dir/saas_starter_templates/$app_name"
  local project_template_dir="$script_dir/$project_name/$app_name/templates/$app_name"

  # Create app directory
  echo -e "\e[32mCreating app '$app_name'...\e[0m" # Green color
  python manage.py startapp "$app_name"

  # Create templates directory inside the app
  mkdir -p "$project_template_dir"

  # Copy and process template files
  if [ -d "$template_dir/templates" ]; then
    find "$template_dir/templates" -type f -name "*.html.template" -print0 | while IFS= read -r -d $'\0' template_file; do
      dest_file="$project_template_dir/$(basename "${template_file%.template}")"
      cp "$template_file" "$dest_file"
    done
  fi

  # Create apps.py with a custom AppConfig
  if [ -f "$template_dir/apps.py.template" ]; then
    if [[ "$app_name" == "admin" ]]; then
      envsubst < "$template_dir/apps.py.template" > "$app_name/apps.py"
    else
      # Capitalize the first letter of the app name
      APP_NAME_CAPITALIZED=$(echo "$app_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
      envsubst < "$template_dir/apps.py.template" > "$app_name/apps.py"
    fi
  fi

  # Create urls.py
  if [ -f "$template_dir/urls.py.template" ]; then
    envsubst < "$template_dir/urls.py.template" > "$app_name/urls.py"
  fi

  # Create views.py
  if [ -f "$template_dir/views.py.template" ]; then
    envsubst < "$template_dir/views.py.template" > "$app_name/views.py"
  fi

  # Create forms.py
  if [ -f "$template_dir/forms.py.template" ]; then
    envsubst < "$template_dir/forms.py.template" > "$app_name/forms.py"
  fi

  echo -e "\e[32mApp '$app_name' created.\e[0m" # Green color
}

# Checks for required template files.
check_templates() {
    local script_dir="$1"
    local required_templates=(
        "core/settings.py.template"
        "core/urls.py.template"
        "templates/base.html.template"
        ".env.template"
        "Dockerfile.template"          # Added Dockerfile
        "docker-compose.yml.template"  # Added docker-compose.yml
    )

    for template in "${required_templates[@]}"; do
        if [ ! -f "$script_dir/saas_starter_templates/$template" ]; then
            echo -e "${YELLOW}Error: Template file not found: $template${NC}"
            echo "Please ensure all template files are present in $script_dir/saas_starter_templates/"
            exit 1
        fi
    done
}

# --- Main Script ---
# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Check for Required Tools ---
echo -e "${GREEN}Checking for required tools...${NC}"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Error: Docker is not installed. Please install it and try again.${NC}"
    exit 1
fi

# Check for Docker Compose (Corrected Logic)
DOCKER_COMPOSE=""
# First, try the new Docker Compose (v2)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
# Then, try the old docker-compose (v1)
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    echo -e "${YELLOW}Error: Docker Compose is not installed. Please install it and try again.${NC}"
    echo "You can install it by following the instructions at:"
    echo "https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}Found Docker Compose command: $DOCKER_COMPOSE${NC}"

# Check for django-admin
if ! command -v django-admin &> /dev/null; then
    echo -e "${YELLOW}Error: django-admin is not installed. Please install Django and try again.${NC}"
    exit 1
fi

# Default PostgreSQL admin information
pg_user="admin"
pg_password="adminpass"
pg_email="admin@test.com"
use_postgres=true

# Store absolute script directory path before changing directories
script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Getting project information
echo "Getting project information..."
read -p "Project name: " project_name

# --- Handle Existing Project Directory ---
if [ -d "$project_name" ]; then
    echo -e "${YELLOW}Error: Project directory '$project_name' already exists. Please choose a different name or remove the existing directory.${NC}"
    exit 1
fi

# Create the project directory.
echo -e "${GREEN}Creating project directory...${NC}"
mkdir "$project_name"
cd "$project_name"

# Before any template operations, check if all templates exist
echo -e "${GREEN}Checking templates...${NC}"
check_templates "$script_dir"

# --- Create docker-compose.yml ---
echo -e "${GREEN}Creating docker-compose.yml...${NC}"
PROJECT_NAME="$project_name" PG_USER="$pg_user" PG_PASSWORD="$pg_password" envsubst < "$script_dir/saas_starter_templates/docker-compose.yml.template" > "docker-compose.yml"

# --- Create a .env file ---
echo -e "${GREEN}Creating .env file...${NC}"
cat <<EOF > .env
DEBUG=True
SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
DATABASE_URL=postgres://${pg_user}:${pg_password}@db:5432/${project_name}
EMAIL_HOST_USER=${pg_email}
EMAIL_HOST_PASSWORD=${pg_password}
EOF

# --- Create a basic Dockerfile ---
echo -e "${GREEN}Creating Dockerfile...${NC}"
PG_USER="$pg_user" PG_EMAIL="$pg_email" PG_PASSWORD="$pg_password" envsubst < "$script_dir/saas_starter_templates/Dockerfile.template" > "Dockerfile"

# Create the Django project *before* Docker build.
echo -e "${GREEN}Creating Django project...${NC}"
django-admin startproject core .

# --- Create Apps ---
echo -e "${GREEN}Creating Apps...${NC}"
apps=("public" "users" "private" "custom_admin" "common")

for app in "${apps[@]}"; do
  create_app "$app"
done

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${NC}"
mkdir templates
mkdir static

# --- Configure core/settings.py ---
echo -e "${GREEN}Configuring core/settings.py...${NC}"
if [ -f "$script_dir/saas_starter_templates/core/settings.py.template" ]; then
    # Create a string with all app names for INSTALLED_APPS
    APPS_STRING=""
    for app in "${apps[@]}"; do
        APPS_STRING+="'$app',"$'\n    '
    done
    PROJECT_NAME="$project_name" APPS_LIST="$APPS_STRING" envsubst < "$script_dir/saas_starter_templates/core/settings.py.template" > "core/settings.py"
else
    echo -e "${YELLOW}Error: settings.py template not found at $script_dir/saas_starter_templates/core/settings.py.template${NC}"
    exit 1
fi

# --- Configure core/urls.py ---
echo -e "${GREEN}Configuring core/urls.py...${NC}"
if [ -f "$script_dir/saas_starter_templates/core/urls.py.template" ]; then
    PROJECT_NAME="$project_name" envsubst < "$script_dir/saas_starter_templates/core/urls.py.template" > "core/urls.py"
else
    echo -e "${YELLOW}Error: urls.py template not found at $script_dir/saas_starter_templates/core/urls.py.template${NC}"
    exit 1
fi

# --- Create base Templates ---
echo -e "${GREEN}Creating base Templates...${NC}"
template_path="$script_dir/saas_starter_templates/templates/base.html.template"
if [ -f "$template_path" ]; then
    cp "$template_path" "templates/base.html"
else
    echo -e "${YELLOW}Error: base.html template not found at $template_path${NC}"
    exit 1
fi

# --- Create a requirements.txt file. ---
echo -e "${GREEN}Creating requirements.txt...${NC}"
cat <<EOF > requirements.txt
Django>=5.0.1
psycopg2-binary>=2.9.9
python-dotenv>=1.0.0
whitenoise>=6.6.0
EOF

# --- Build and start the application using Docker Compose ---
echo -e "${GREEN}Building and starting the application...${NC}"
$DOCKER_COMPOSE build
$DOCKER_COMPOSE up -d

echo -e "${GREEN}Project '$project_name' created and started successfully.${NC}"
echo "The application is running in Docker containers."
echo "To access the application, open your web browser and go to: http://localhost:8000"
echo ""
echo "To stop the application, run: $DOCKER_COMPOSE down"
echo "To remove the project, run: $DOCKER_COMPOSE down --volumes && rm -rf $project_name"
