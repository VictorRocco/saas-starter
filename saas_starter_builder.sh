#!/bin/bash

# --- Colors (for nicer output) ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

  # Create templates directory
  mkdir -p "$project_template_dir"

  # Copy templates
  if [ -d "$template_dir/templates" ]; then
    find "$template_dir/templates" -name "*.template" -print0 | while IFS= read -r -d $'\0' template_file; do
      # Extract relative path without the .template extension
      relative_path=$(echo "$template_file" | sed -e "s|$template_dir/templates/||" -e "s/\.template$//")
      target_file="$script_dir/$project_name/$app_name/$relative_path"
      mkdir -p "$(dirname "$target_file")"
      PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$template_file" > "$target_file"
      echo "Copied and processed: $template_file -> $target_file"
    done
  fi

  # Copy views, models, forms, urls
  for file in views models forms urls; do
    if [ -f "$template_dir/$file.py.template" ]; then
      PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$template_dir/$file.py.template" > "$script_dir/$project_name/$app_name/$file.py"
      echo "Copied and processed: $template_dir/$file.py.template -> $script_dir/$project_name/$app_name/$file.py"
    fi
  done

    if [[ "$app_name" == "public" ]]; then
        # Copy home.html template
        local home_template="$template_dir/templates/$app_name/home.html.template"
        local target_home="$project_template_dir/home.html"
        if [ -f "$home_template" ]; then
            mkdir -p "$(dirname "$target_home")"
            PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$home_template" > "$target_home"
            echo "Copied and processed: $home_template -> $target_home"
        fi

        # Copy navbar.html template
        local components_dir="$script_dir/$project_name/templates/components"
        mkdir -p "$components_dir"
        local navbar_template="$script_dir/saas_starter_templates/templates/components/navbar.html.template"
        if [ -f "$navbar_template" ]; then
          cp "$navbar_template" "$components_dir/navbar.html"
        fi
    fi
}

# Checks for required template files.
check_templates() {
    local script_dir="$1"
    local required_templates=(
        "core/settings.py.template"
        "core/urls.py.template"
        "templates/base.html.template"
        ".env.template"
        "Dockerfile.template"
        "docker-compose.yml.template"
        ".dockerignore.template"
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

# Check for required tools
echo "Checking for required tools..."
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

# Determine Docker Compose command (v1 or v2)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo "Found Docker Compose command: docker-compose (v1)"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo "Found Docker Compose command: docker compose (v2)"
else
    echo "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

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

# --- Get Project Information ---
echo "Getting project information..."
read -p "Project name: " project_name

# --- Check if project directory already exists ---
if [ -d "$project_name" ]; then
    echo -e "${RED}Error: Project directory '$project_name' already exists.${NC} Please run '${YELLOW}rm -rf $project_name${NC}' to delete the existing project first.  \e[1mUse this command with extreme caution! Make sure you have a backup if needed.\e[0m"
    exit 1
fi

# --- Create Project Directory ---
echo -e "${GREEN}Creating project directory...${NC}"
mkdir "$project_name"
cd "$project_name"

# --- Check if all templates exist before any operations ---
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

# --- Create .dockerignore ---
echo -e "${GREEN}Creating .dockerignore...${NC}"
cp "$script_dir/saas_starter_templates/.dockerignore.template" ".dockerignore"

# --- Create Django Project ---
echo -e "${GREEN}Creating Django project...${NC}"
django-admin startproject core .

# --- Create Apps ---
echo -e "${GREEN}Creating apps...${NC}"
apps=(public users)  # Add or remove apps as needed
for app in "${apps[@]}"; do
  create_app "$app"
done

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${NC}"
mkdir templates
mkdir static
mkdir templates/components

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
printf "Available make commands:\n"
printf "• To start the application: ${YELLOW}make up${NC}\n"
printf "• To stop the application: ${YELLOW}make down${NC}\n"
printf "• To remove the project: ${YELLOW}make clean${NC}\n"
printf "• To view logs: ${YELLOW}make logs${NC}\n"
printf "• To see all available commands: ${YELLOW}make help${NC}\n"
