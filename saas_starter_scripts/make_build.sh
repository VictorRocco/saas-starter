#!/bin/bash

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR" || exit 1

# Source common variables and functions with SKIP_TRACKING=1
export SKIP_TRACKING=1
source "$SCRIPT_DIR/make_common.sh" || {
    echo "❌ Failed to source make_common.sh"
    exit 1
}

# Check if there's already an active project
if [ -f "$ROOT_DIR/saas_starter_tracking.json" ]; then
    EXISTING_PROJECT=$(python3 "$SCRIPT_DIR/utils.py" read "$ROOT_DIR/saas_starter_tracking.json" "project_name")
    if [ $? -eq 0 ]; then
        printf "${RED}❌ Active project '${EXISTING_PROJECT}' already exists.${RESET}\n"
        printf "${YELLOW}Please run 'make destroy' first if you want to create a new project.${RESET}\n"
        exit 1
    fi
fi

# --- Get Project Information ---
echo "Getting project information..."
read -p "Project name: " project_name

# --- Redirect output to log file ---
LOG_FILE="$ROOT_DIR/saas_starter_log.txt"

# --- Setup logging after getting project name ---
if ! tee --version > /dev/null 2>&1; then
    echo "tee command not found! Logging will not work."
else
    exec &> >(sed 's/\x1B\[[0-9;]*[mG]//g' | tee "$LOG_FILE")
    echo "Starting the saas_starter_builder.sh script. Logging to $LOG_FILE"
fi

# --- Helper Functions ---

# Function to process templates with environment variables
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        echo "Template file $template_file not found!"
        return 1
    fi
    
    # Export all variables needed in templates
    export project_name
    export pg_user
    export pg_password
    export pg_email
    export SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
    
    # Process template with envsubst
    envsubst < "$template_file" > "$output_file"
}

# Function to process all templates in a directory
process_templates_recursive() {
    local src_dir="$1"
    local dest_dir="$2"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dest_dir"
    
    # Find all .template files and process them
    find "$src_dir" -type f -name "*.template" | while read -r template_file; do
        # Get the relative path from src_dir
        local rel_path="${template_file#$src_dir/}"
        # Remove .template extension for the destination file
        local dest_file="$dest_dir/${rel_path%.template}"
        # Create subdirectories if needed
        mkdir -p "$(dirname "$dest_file")"
        # Process the template
        process_template "$template_file" "$dest_file"
    done
    
    # Copy non-template files (like __init__.py)
    find "$src_dir" -type f ! -name "*.template" | while read -r file; do
        local rel_path="${file#$src_dir/}"
        local dest_file="$dest_dir/$rel_path"
        mkdir -p "$(dirname "$dest_file")"
        cp "$file" "$dest_file"
    done
}

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ${DOCKER_COMPOSE_COMMAND} exec db pg_isready -U ${pg_user} > /dev/null 2>&1; then
            echo "PostgreSQL is ready!"
            return 0
        fi
        echo "Attempt $attempt of $max_attempts: PostgreSQL is not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Error: PostgreSQL did not become ready in time"
    return 1
}

# Creates a Django app with basic structure
create_app() {
    local app_name="$1"
    
    echo -e "${GREEN}Creating app '$app_name'...${RESET}" 
    django-admin startapp "$app_name"
    
    # Process app templates if they exist
    if [ -d "$ROOT_DIR/saas_starter_templates/$app_name" ]; then
        process_templates_recursive "$ROOT_DIR/saas_starter_templates/$app_name" "$app_name"
        echo "Processed $app_name templates"
    fi
    
    # Create app-specific template directory
    mkdir -p "templates/${app_name}"
    touch "templates/${app_name}/__init__.py"
}

# --- Main Script ---

# Check for required tools
echo "Checking for required tools..."
if ! check_command "docker"; then
    exit 1
fi

# Check for django-admin
if ! check_command "django-admin"; then
    printf "${YELLOW}Error: django-admin is not installed. Please install Django and try again.${RESET}\n"
    exit 1
fi

# Default PostgreSQL admin information
pg_user="admin"
pg_password="adminpasswd"
pg_email="admin@test.com"
use_postgres=true

# Store absolute script directory path before changing directories
script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# --- Check if project directory already exists ---
if [ -d "$project_name" ]; then
    printf "${RED}Error: Project directory '$project_name' already exists.${RESET} Please run '${YELLOW}rm -rf $project_name${RESET}' to delete the existing project first.  \e[1mUse this command with extreme caution! Make sure you have a backup if needed.\e[0m\n"
    exit 1
fi

# --- Create Project Directory and Setup ---
echo -e "${GREEN}Creating project directory...${RESET}"
mkdir "$project_name"
cd "$project_name"

# --- Create Django Project First ---
echo -e "${GREEN}Creating Django project...${RESET}"
django-admin startproject core .

# --- Process and Copy Configuration Files ---
echo -e "${GREEN}Processing configuration files...${RESET}"
TEMPLATES_DIR="$ROOT_DIR/saas_starter_templates"

# Process each template file
process_template "$TEMPLATES_DIR/docker-compose.yml.template" "docker-compose.yml"
process_template "$TEMPLATES_DIR/Dockerfile.template" "Dockerfile"
process_template "$TEMPLATES_DIR/.env.template" ".env"
process_template "$TEMPLATES_DIR/.dockerignore.template" ".dockerignore"
process_template "$TEMPLATES_DIR/requirements.txt.template" "requirements.txt"

# --- Create Apps First ---
echo -e "${GREEN}Creating apps...${RESET}"
apps=(public dashboard users common)
for app in "${apps[@]}"; do
    django-admin startapp "$app"
    if [ -d "$ROOT_DIR/saas_starter_templates/$app" ]; then
        process_templates_recursive "$ROOT_DIR/saas_starter_templates/$app" "$app"
        echo "Processed $app templates"
    fi
    mkdir -p "templates/${app}"
    touch "templates/${app}/__init__.py"
done

# --- Copy Core Templates ---
echo -e "${GREEN}Copying and processing core templates...${RESET}"
if [ -d "$TEMPLATES_DIR/core" ]; then
    process_templates_recursive "$TEMPLATES_DIR/core" "core"
fi

# --- Copy Templates Structure ---
echo -e "${GREEN}Copying template structure...${RESET}"
if [ -d "$TEMPLATES_DIR/templates" ]; then
    process_templates_recursive "$TEMPLATES_DIR/templates" "templates"
fi

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${RESET}"
mkdir -p static/css static/js static/img
echo "Created static asset directories"

# --- Create tracking file ---
echo -e "${GREEN}Creating tracking file...${RESET}"
echo "{\"project_name\": \"$project_name\"}" > "$ROOT_DIR/saas_starter_tracking.json"

# --- Build and start the application using Docker Compose ---
echo -e "${GREEN}Building and starting the application...${RESET}"
${DOCKER_COMPOSE_COMMAND} build
${DOCKER_COMPOSE_COMMAND} up -d

# Wait for PostgreSQL to be ready
if ! wait_for_postgres; then
    echo "Error: Database failed to start. Check the logs with 'make logs'"
    exit 1
fi

# Install dependencies first
${DOCKER_COMPOSE_COMMAND} exec web pip install -r requirements.txt

# Run migrations for Django's built-in apps first
${DOCKER_COMPOSE_COMMAND} exec web python manage.py migrate --noinput

# Run makemigrations for our apps
${DOCKER_COMPOSE_COMMAND} exec web python manage.py makemigrations users
${DOCKER_COMPOSE_COMMAND} exec web python manage.py makemigrations public
${DOCKER_COMPOSE_COMMAND} exec web python manage.py makemigrations dashboard
${DOCKER_COMPOSE_COMMAND} exec web python manage.py makemigrations common

# Apply all migrations
${DOCKER_COMPOSE_COMMAND} exec web python manage.py migrate --noinput

# Create superuser
${DOCKER_COMPOSE_COMMAND} exec web python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${pg_user}', '${pg_email}', '${pg_password}') if not User.objects.filter(username='${pg_user}').exists() else None"

echo -e "${GREEN}Project '$project_name' created and started successfully.${RESET}"
echo "The application is running in Docker containers."
echo "To access the application, open your web browser and go to: http://localhost:8000"
echo ""
printf "Available make commands:\n"
printf "• To see all available commands: ${YELLOW}make help${RESET}\n"
printf "• The application should be running in Docker containers. To view logs: ${YELLOW}make logs${RESET}\n"
