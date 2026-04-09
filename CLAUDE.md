# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Life Dashboard** — Application personnelle de gestion de vie quotidienne. Tableau de bord central donnant accès à différents modules :

- **Contacts** — Gestion de la liste de contacts personnels et professionnels
- **Immobilier** — Suivi des biens immobiliers (propriétés, locataires, charges, revenus)
- **Entreprises** — Gestion d'entreprises avec génération de devis et factures (PDF)
- **Budget** — Suivi des revenus, dépenses, épargne, investissements
- **Réseaux sociaux** — Agrégation et gestion des comptes sociaux
- **Activités** — Suivi d'activités sportives, hobbies, habitudes
- **Langues** — Suivi de l'apprentissage de langues étrangères
- **Messagerie** — Centralisation des emails et messageries
- **SMS/Textos** — Gestion des textos
- **Agenda** — Organisation des rendez-vous et événements

Architecture : Rails 8.0 monolith + Vue 3 SPA frontend. Single domain, Vue gère tout le UI, Rails sert d'API backend. Vite pour le build frontend.

## Rules

- **Do NOT run the dev server, tests, or linters** unless explicitly asked.
- Toujours demander confirmation avant de lancer `db:migrate` ou toute commande destructive.
- Le projet est en français (UI, commentaires) sauf le code (variables, méthodes en anglais).

## Common Commands

### Development
```bash
foreman start -f Procfile.dev    # Rails + Vite dev servers
bin/rails s                      # Rails server on port 3000
bin/vite dev                     # Vite dev server with HMR
```

### Dependencies
```bash
bundle install        # Ruby gems
npm install          # Node packages
```

### Database
```bash
rails db:create db:migrate
bundle exec annotaterb models  # Update model annotations after migrations
```

### Testing (Minitest)
```bash
rails test                          # Run all tests
rails test test/path/to/file.rb    # Run single test file
rails test test/path/to/file.rb:42 # Run specific test at line
```

### Linting
```bash
npm run lint              # ESLint for Vue/JS
npm run lint:fix          # ESLint with auto-fix
bundle exec rubocop       # RuboCop for Ruby
bundle exec rubocop -a    # RuboCop with auto-fix
```

## Architecture

### Request Flow
1. All HTML requests route to `SpaController#index` via catch-all route
2. Vue Router handles client-side navigation
3. API endpoints under `/api` namespace return JSON
4. CSRF token from Rails meta tag attached to all Axios requests

### Frontend Structure (`app/frontend/`)
- **entrypoints/application.js** - Vue app bootstrap with Pinia and Router
- **plugins/axios.js** - Axios instance with CSRF and auth token handling
- **stores/** - Pinia stores (auth, api, counter)
- **composables/** - Reusable Vue composition functions
- **router/** - Vue Router config with navigation guards
- **pages/** - Page components
- **components/** - Reusable Vue components

### Backend Patterns
- `ApplicationController` includes Pundit (authorization) and Pagy (pagination)
- Devise for authentication
- Background jobs via GoodJob (PostgreSQL-based, no Redis)
- Rate limiting via Rack::Attack
- Security headers via SecureHeaders

### Pagy 43 Usage
```ruby
@pagy, @records = pagy(:offset, Model.all)
@pagy, @records = pagy(:keyset, Model.order(:id).all)
```

## Key Dependencies

**Backend:** Rails 8.0, PostgreSQL, Devise, Pundit, GoodJob, Pagy 43, PaperTrail
**Frontend:** Vue 3.5, Vite 5, Pinia, Vue Router, Axios, Tailwind CSS 3.4
**Requires:** Ruby 3.3.5, Node 20.x
