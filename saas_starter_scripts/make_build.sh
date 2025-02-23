#!/bin/bash

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR" || exit 1

# Check if there's already an active project
if [ -f "$ROOT_DIR/saas_starter_tracking.json" ]; then
    EXISTING_PROJECT=$(python3 "$SCRIPT_DIR/utils.py" read "$ROOT_DIR/saas_starter_tracking.json" "project_name")
    if [ $? -eq 0 ]; then
        printf "${RED}❌ Active project '${EXISTING_PROJECT}' already exists.${RESET}\n"
        printf "${YELLOW}Please run 'make destroy' first if you want to create a new project.${RESET}\n"
        exit 1
    fi
fi

# Source common variables and functions with SKIP_TRACKING=1
export SKIP_TRACKING=1
source "$SCRIPT_DIR/make_common.sh" || {
    printf "${RED}❌ Failed to source make_common.sh${RESET}\n"
    exit 1
}

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

# Creates a Django app with basic structure
create_app() {
  local app_name="$1"
  
  echo -e "${GREEN}Creating app '$app_name'...${RESET}" 
  python manage.py startapp "$app_name"

  # Create basic urls.py
  cat > "$app_name/urls.py" <<EOF
from django.urls import path
from . import views

app_name = '$app_name'

urlpatterns = [
]
EOF
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

# --- Create Project Directory ---
echo -e "${GREEN}Creating project directory...${RESET}"
mkdir "$project_name"
echo "mkdir $project_name"
cd "$project_name"

# --- Create docker-compose.yml ---
echo -e "${GREEN}Creating docker-compose.yml...${RESET}"
cat > "docker-compose.yml" <<EOF
version: '3.8'

services:
  web:
    build: .
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    environment:
      - DEBUG=True
      - SECRET_KEY=your-secret-key
      - DATABASE_URL=postgresql://${pg_user}:${pg_password}@db:5432/${project_name}
    depends_on:
      - db
  
  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${project_name}
      - POSTGRES_USER=${pg_user}
      - POSTGRES_PASSWORD=${pg_password}

volumes:
  postgres_data:
EOF

# --- Create a .env file ---
echo -e "${GREEN}Creating .env file...${RESET}"
cat > .env <<EOF
DEBUG=True
SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')
DATABASE_URL=postgresql://${pg_user}:${pg_password}@db:5432/${project_name}  # Changed from localhost to db
EMAIL_HOST_USER=${pg_email}
EMAIL_HOST_PASSWORD=${pg_password}
POSTGRES_HOST=db  # Added explicit host configuration
EOF

# --- Create a basic Dockerfile ---
echo -e "${GREEN}Creating Dockerfile...${RESET}"
cat > "Dockerfile" <<EOF
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN apt-get update && apt-get install -y \\
    build-essential \\
    libpq-dev \\
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EOF

# --- Create .dockerignore ---
echo -e "${GREEN}Creating .dockerignore...${RESET}"
cat > ".dockerignore" <<EOF
.git
.gitignore
.env
*.pyc
__pycache__
.DS_Store
*.sqlite3
media
staticfiles
.venv
venv
EOF

# --- Create Django Project ---
echo -e "${GREEN}Creating Django project...${RESET}"
django-admin startproject core .

# --- Create Apps ---
echo -e "${GREEN}Creating apps...${RESET}"
apps=(public dashboard users common)  # Changed 'admin' to 'dashboard'
for app in "${apps[@]}"; do
  create_app "$app"
done

# --- Create Project-Level Directories ---
echo -e "${GREEN}Creating Project-Level Directories...${RESET}"
mkdir -p static/css static/js static/img
echo "Created static asset directories"

# --- Configure core/settings.py ---
echo -e "${GREEN}Configuring core/settings.py...${RESET}"
cat > "core/settings.py" <<EOF
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-here')

DEBUG = os.getenv('DEBUG', 'False') == 'True'

ALLOWED_HOSTS = ['*']  # Configure this appropriately in production

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'whitenoise.runserver_nostatic',
    # Local apps
    'public.apps.PublicConfig',
    'dashboard.apps.DashboardConfig',  # Changed from admin to dashboard
    'users.apps.UsersConfig',
    'common.apps.CommonConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('POSTGRES_DB', '${project_name}'),
        'USER': os.getenv('POSTGRES_USER', '${pg_user}'),
        'PASSWORD': os.getenv('POSTGRES_PASSWORD', '${pg_password}'),
        'HOST': os.getenv('POSTGRES_HOST', 'db'),  # Changed from 'localhost' to 'db'
        'PORT': os.getenv('POSTGRES_PORT', '5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']

MEDIA_URL = 'media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Whitenoise configuration
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
EOF

# --- Configure core/urls.py ---
echo -e "${GREEN}Configuring core/urls.py...${RESET}"
cat > "core/urls.py" <<EOF
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('public.urls')),
    path('dashboard/', include('users.urls')),
    path('admin-dashboard/', include('dashboard.urls')),  # Changed from admin to dashboard
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
EOF

# --- Create a requirements.txt file ---
echo -e "${GREEN}Creating requirements.txt...${RESET}"
cat > requirements.txt <<EOF
Django>=5.0.1
psycopg2-binary>=2.9.9
python-dotenv>=1.0.0
whitenoise>=6.6.0
dj-database-url>=2.1.0
EOF

# --- Create tracking file ---
echo -e "${GREEN}Creating tracking file...${RESET}"
echo "{\"project_name\": \"$project_name\"}" > "$ROOT_DIR/saas_starter_tracking.json"
file in the 
# --- Create templates directory structure ---
echo -e "${GREEN}Creating template structure...${RESET}"
mkdir -p templates/public
mkdir -p templates/dashboard
mkdir -p templates/users

# Create base template
cat > templates/base.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}{% endblock %}</title>
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>
EOF

# Create homepage template
cat > templates/public/home.html <<EOF
{% extends "base.html" %}

{% block title %}Welcome{% endblock %}

{% block content %}
    <h1>Welcome to ${project_name}</h1>
    <p>Your application is running successfully!</p>
{% endblock %}
EOF

# Configure public/views.py
cat > public/views.py <<EOF
from django.views.generic import TemplateView

class HomeView(TemplateView):
    template_name = 'public/home.html'
EOF

# Configure public/urls.py
cat > public/urls.py <<EOF
from django.urls import path
from . import views

app_name = 'public'

urlpatterns = [
    path('', views.HomeView.as_view(), name='home'),
]
EOF

# --- Build and start the application using Docker Compose ---
echo -e "${GREEN}Building and starting the application...${RESET}"
${DOCKER_COMPOSE_COMMAND} build
${DOCKER_COMPOSE_COMMAND} up -d

# Apply migrations and create superuser after starting containers
echo -e "${GREEN}Applying migrations and creating superuser...${RESET}"
${DOCKER_COMPOSE_COMMAND} up -d
sleep 10  # Wait for database to be ready
${DOCKER_COMPOSE_COMMAND} exec web python manage.py migrate
${DOCKER_COMPOSE_COMMAND} exec web python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${pg_user}', '${pg_email}', '${pg_password}') if not User.objects.filter(username='${pg_user}').exists() else None"

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
