#!/bin/bash

# --- Debugging: Check if the script is running ---
echo "Script started!"

# --- Redirect output to log file ---
LOG_FILE="saas_starter_log.txt"

# --- Debugging: Check if tee is working and permissions are correct ---
if ! tee --version > /dev/null 2>&1; then
  echo "tee command not found! Logging will not work."
else
  echo "tee command found."
  # --- Try simple redirection first, stripping colors ---
  exec &> >(sed 's/\x1B\[[0-9;]*[mG]//g' | tee "$LOG_FILE")
  echo "Starting the saas_starter_builder.sh script. Logging to $LOG_FILE"
fi

# --- Colors (for nicer output) ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m' # No Color

# --- Helper Functions ---

# Creates a Django app and its basic structure.
create_app() {
  local app_name="$1"
  local script_dir="$(dirname "$0")"  # Get the script's directory
  local template_dir="$script_dir/saas_starter_templates/$app_name"
  local project_template_dir="$app_name/templates/$app_name"

  # Create app directory
  echo -e "\e[32mCreating app '$app_name'...\e[0m" # Green color
  python manage.py startapp "$app_name"

  # Create templates directory
  mkdir -p "$project_template_dir"
  echo "mkdir -p $project_template_dir"

  # Copy templates
  if [ -d "$template_dir/templates" ]; then
    # Process all .html.template files first
    find "$template_dir/templates/$app_name" -name "*.html.template" -print0 | while IFS= read -r -d $'\0' template_file; do
      relative_path=$(echo "$template_file" | sed -e "s|$template_dir/templates/$app_name/||" -e "s/\.template$//")
      target_file="$project_template_dir/$relative_path"
      mkdir -p "$(dirname "$target_file")"
      echo "mkdir -p $(dirname "$target_file")"
      PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$template_file" > "$target_file"
      echo "PROJECT_NAME=$project_name APP_NAME=$app_name envsubst < $template_file > $target_file"
      echo "Processed template: $template_file -> $target_file"
    done

    # Then copy any remaining .html files that don't have a .template version
    find "$template_dir/templates/$app_name" -name "*.html" ! -name "*.template" -print0 | while IFS= read -r -d $'\0' template_file; do
      relative_path=$(echo "$template_file" | sed -e "s|$template_dir/templates/$app_name/||")
      target_file="$project_template_dir/$relative_path"
      # Only copy if a .template version doesn't exist
      if [ ! -f "${template_file}.template" ]; then
        mkdir -p "$(dirname "$target_file")"
        echo "mkdir -p $(dirname "$target_file")"
        cp "$template_file" "$target_file"
        echo "cp $template_file $target_file"
        echo "Copied: $template_file -> $target_file"
      fi
    done

    # Then process all other .template files
    find "$template_dir/templates/$app_name" -name "*.template" ! -name "*.html.template" -print0 | while IFS= read -r -d $'\0' template_file; do
      relative_path=$(echo "$template_file" | sed -e "s|$template_dir/templates/$app_name/||" -e "s/\.template$//")
      target_file="$project_template_dir/$relative_path"
      mkdir -p "$(dirname "$target_file")"
      echo "mkdir -p $(dirname "$target_file")"
      PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$template_file" > "$target_file"
      echo "PROJECT_NAME=$project_name APP_NAME=$app_name envsubst < $template_file > $target_file"
      echo "Processed template: $template_file -> $target_file"
    done
  fi

  # Copy core app files (views.py, urls.py, models.py, forms.py, apps.py)
  for file in views.py urls.py models.py forms.py apps.py; do
    template_file="$template_dir/${file}.template"
    target_file="$app_name/$file"
    
    if [ -f "$template_file" ]; then
      echo "Processing $template_file -> $target_file"
      PROJECT_NAME="$project_name" APP_NAME="$app_name" envsubst < "$template_file" > "$target_file"
      echo "PROJECT_NAME=$project_name APP_NAME=$app_name envsubst < $template_file > $target_file"
    elif [ "$file" = "urls.py" ]; then
      # Create a basic urls.py if template doesn't exist
      echo "Creating basic $file for $app_name"
      cat > "$target_file" <<EOF
from django.urls import path
from . import views

app_name = '$app_name'

urlpatterns = [
    path('', views.home, name='home'),
    path('about/', views.about, name='about'),
    path('contact/', views.contact, name='contact'),
]
EOF
      echo "cat > $target_file <<EOF"
    elif [ "$file" = "views.py" ]; then
      # Create basic views if they don't exist
      echo "Creating basic views.py for $app_name"
      cat > "$target_file" <<EOF
from django.shortcuts import render

def home(request):
    return render(request, '$app_name/home.html')

def about(request):
    return render(request, '$app_name/about.html')

def contact(request):
    return render(request, '$app_name/contact.html')
EOF
      echo "cat > $target_file <<EOF"
    fi
  done

  # Create basic templates if they don't exist
  if [ ! -f "$project_template_dir/home.html" ]; then
    cat > "$project_template_dir/home.html" <<EOF
{% extends "base.html" %}

{% block title %}Home - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">Welcome to ${project_name}</h1>
    <p class="subtitle">This is the home page.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/home.html <<EOF"
  fi

  if [ ! -f "$project_template_dir/about.html" ]; then
    cat > "$project_template_dir/about.html" <<EOF
{% extends "base.html" %}

{% block title %}About - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">About Us</h1>
    <p class="subtitle">Learn more about ${project_name}.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/about.html <<EOF"
  fi

  if [ ! -f "$project_template_dir/contact.html" ]; then
    cat > "$project_template_dir/contact.html" <<EOF
{% extends "base.html" %}

{% block title %}Contact - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">Contact Us</h1>
    <p class="subtitle">Get in touch with ${project_name}.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/contact.html <<EOF"
  fi

  # Special handling for public app
  if [[ "$app_name" == "public" ]]; then
    # Create examples directory
    mkdir -p "$project_template_dir/examples"
    echo "mkdir -p $project_template_dir/examples"

    # Create example templates
    cat > "$project_template_dir/examples/bulma.html" <<EOF
{% extends "base.html" %}

{% block title %}Bulma Examples - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">Bulma Examples</h1>
    <p class="subtitle">Examples of Bulma CSS components.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/examples/bulma.html <<EOF"

    cat > "$project_template_dir/examples/alpine.html" <<EOF
{% extends "base.html" %}

{% block title %}Alpine.js Examples - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">Alpine.js Examples</h1>
    <p class="subtitle">Examples of Alpine.js functionality.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/examples/alpine.html <<EOF"

    cat > "$project_template_dir/examples/htmx.html" <<EOF
{% extends "base.html" %}

{% block title %}HTMX Examples - ${project_name}{% endblock %}

{% block content %}
<section class="section">
  <div class="container">
    <h1 class="title">HTMX Examples</h1>
    <p class="subtitle">Examples of HTMX functionality.</p>
  </div>
</section>
{% endblock %}
EOF
    echo "cat > $project_template_dir/examples/htmx.html <<EOF"
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
            echo -e "${YELLOW}Error: Template file not found: $template${RESET}"
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
    echo -e "${YELLOW}Error: django-admin is not installed. Please install Django and try again.${RESET}"
    exit 1
fi

# Default PostgreSQL admin information
pg_user="admin"
pg_password="adminpasswd"
pg_email="admin@test.com"
use_postgres=true

# Store absolute script directory path before changing directories
script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# --- Get Project Information ---
echo "Getting project information..."
read -p "Project name: " project_name

# --- Check if project directory already exists ---
if [ -d "$project_name" ]; then
    echo -e "${RED}Error: Project directory '$project_name' already exists.${RESET} Please run '${YELLOW}rm -rf $project_name${RESET}' to delete the existing project first.  \e[1mUse this command with extreme caution! Make sure you have a backup if needed.\e[0m"
    exit 1
fi

# --- Create Project Directory ---
echo -e "${GREEN}Creating project directory...${RESET}"
mkdir "$project_name"
echo "mkdir $project_name"
cd "$project_name"

# --- Check if all templates exist before any operations ---
check_templates "$script_dir"

# --- Create docker-compose.yml ---
echo -e "${GREEN}Creating docker-compose.yml...${RESET}"
PROJECT_NAME="$project_name" PG_USER="$pg_user" PG_PASSWORD="$pg_password" envsubst < "$script_dir/saas_starter_templates/docker-compose.yml.template" > "docker-compose.yml"
echo "PROJECT_NAME=$project_name PG_USER=$pg_user PG_PASSWORD=$pg_password envsubst < $script_dir/saas_starter_templates/docker-compose.yml.template > docker-compose.yml"

# --- Create a .env file ---
echo -e "${GREEN}Creating .env file...${RESET}"
cat <<EOF > .env
DEBUG=True
SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
DATABASE_URL=postgresql://${pg_user}:${pg_password}@localhost:5432/${project_name}
EMAIL_HOST_USER=${pg_email}
EMAIL_HOST_PASSWORD=${pg_password}
EOF
echo "cat <<EOF > .env"

# --- Create a basic Dockerfile ---
echo -e "${GREEN}Creating Dockerfile...${RESET}"
PG_USER="$pg_user" PG_EMAIL="$pg_email" PG_PASSWORD="$pg_password" envsubst < "$script_dir/saas_starter_templates/Dockerfile.template" > "Dockerfile"
echo "PG_USER=$pg_user PG_EMAIL=$pg_email PG_PASSWORD=$pg_password  envsubst < $script_dir/saas_starter_templates/Dockerfile.template > Dockerfile"

# --- Create .dockerignore ---
echo -e "${GREEN}Creating .dockerignore...${RESET}"
cp "$script_dir/saas_starter_templates/.dockerignore.template" ".dockerignore"
echo "cp $script_dir/saas_starter_templates/.dockerignore.template .dockerignore"

# --- Create Django Project ---
echo -e "${GREEN}Creating Django project...${RESET}"
django-admin startproject core .

# --- Create Apps ---
echo -e "${GREEN}Creating apps...${RESET}"
apps=(public users)  # Add or remove apps as needed
for app in "${apps[@]}"; do
  create_app "$app"
done

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${RESET}"
mkdir templates
echo "mkdir templates"
mkdir static
echo "mkdir static"
mkdir templates/components
echo "mkdir templates/components"

# --- Configure core/settings.py ---
echo -e "${GREEN}Configuring core/settings.py...${RESET}"
if [ -f "$script_dir/saas_starter_templates/core/settings.py.template" ]; then
    # Create a string with all app names for INSTALLED_APPS
    APPS_LIST=""
    for app in "${apps[@]}"; do
        APPS_LIST+="    '$app',\n"
    done
    # Remove the trailing newline and escape the newlines
    APPS_LIST=$(echo -e "${APPS_LIST%\\n}" | sed 's/\\n/\\\\n/g')
    export APPS_LIST
    export DJANGO_SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
    export DEBUG=True
    PROJECT_NAME="$project_name" envsubst < "$script_dir/saas_starter_templates/core/settings.py.template" > "core/settings.py"
    echo "PROJECT_NAME=$project_name envsubst < $script_dir/saas_starter_templates/core/settings.py.template > core/settings.py"
else
    echo -e "${YELLOW}Error: settings.py template not found at $script_dir/saas_starter_templates/core/settings.py.template${RESET}"
    exit 1
fi

# --- Configure core/urls.py ---
echo -e "${GREEN}Configuring core/urls.py...${RESET}"
if [ -f "$script_dir/saas_starter_templates/core/urls.py.template" ]; then
    PROJECT_NAME="$project_name" envsubst < "$script_dir/saas_starter_templates/core/urls.py.template" > "core/urls.py"
    echo "PROJECT_NAME=$project_name envsubst < $script_dir/saas_starter_templates/core/urls.py.template > core/urls.py"
else
    echo -e "${YELLOW}Error: urls.py template not found at $script_dir/saas_starter_templates/core/urls.py.template${RESET}"
    exit 1
fi

# --- Create base Templates ---
echo -e "${GREEN}Creating base Templates...${RESET}"
template_path="$script_dir/saas_starter_templates/templates/base.html.template"
if [ -f "$template_path" ]; then
    cp "$template_path" "templates/base.html"
    echo "cp $template_path templates/base.html"
else
    echo -e "${YELLOW}Error: base.html template not found at $template_path${RESET}"
    exit 1
fi

# --- Create a requirements.txt file. ---
echo -e "${GREEN}Creating requirements.txt...${RESET}"
cat <<EOF > requirements.txt
Django>=5.0.1
psycopg2-binary>=2.9.9
python-dotenv>=1.0.0
whitenoise>=6.6.0
dj-database-url>=2.1.0
EOF
echo "cat <<EOF > requirements.txt"

# --- Create tracking file ---
echo -e "${GREEN}Creating tracking file...${RESET}"
echo "{\"project_name\": \"$project_name\"}" > ../saas_starter_tracking.json
echo "echo {\"project_name\": \"$project_name\"} > ../saas_starter_tracking.json"

# --- Build and start the application using Docker Compose ---
echo -e "${GREEN}Building and starting the application...${RESET}"
$DOCKER_COMPOSE build
$DOCKER_COMPOSE up -d

echo -e "${GREEN}Project '$project_name' created and started successfully.${RESET}"
echo "The application is running in Docker containers."
echo "To access the application, open your web browser and go to: http://localhost:8000"
echo ""
printf "Available make commands:\n"
printf "• To start the application: ${YELLOW}make up${RESET}\n"
printf "• To stop the application: ${YELLOW}make down${RESET}\n"
printf "• To remove the project: ${YELLOW}make clean${RESET}\n"
printf "• To view logs: ${YELLOW}make logs${RESET}\n"
printf "• To see all available commands: ${YELLOW}make help${RESET}\n"
