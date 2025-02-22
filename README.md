# **saas-starter**

A Saas starter for python heavy developers, like backend / cloud developers, AI / ML / Data Scientists engineers.

For developers who want to give a next step and launch their application as a SaaS service.
Or companies who want to add a web user interface to their offered product or service.

## TECHNICAL STACK
- Django (backend framework).
    - Django REST framework (API).
    - Whitenoise (static files).
    - Psycopg2 (PostgreSQL adapter).
- HTMX (frontend to backend communication for CRUD operations with the simplicity of HTML).
- Alpine.js (simple vanilla JS library for DOM manipulation).
- Bulma CSS (simple CSS styling without JavaScript).
- PostgreSQL (database).
- Deployment: .env + Docker + Uvicorn.
- Environment: localhost (docker) + Railway.

## STARTER PAGES
- Public: 
  - Home: Landing page.
  - Login: Login page.
  - Register: Register page.
  - Contact: Contact page.
  - About: About page.
  - Bulma CSS: Bulma CSS examples page.
  - Alpine.js: Alpine.js examples page.
  - HTMX: HTMX examples page.
  - Navigation Bar: Navigation bar.
- User Private: 
  - Dashboard: Dashboard page.
  - Profile: Profile page.
  - Settings: Settings page.
- Admin Private: 
  - Dashboard: Dashboard page.
  - Profile: Profile page.
  - Settings: Settings page.
  - Users CRUD.

## STARTER DATABASE
- Administrator: 
  - user: admin.
  - password: adminpasswd
  - email: admin@test.com

## PROJECT INITIALIZATION 

Use the Makefile to initialize the project.

```bash
make build
```





