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

## Subagent Alfred (intendant)

Ce dashboard est piloté à distance par le subagent global **Alfred** (`~/.claude/agents/alfred.md`), via les skills `life-dashboard` (lecture) et `life-dashboard-write` (écriture étendue). Alfred est l'intendant personnel de Sylvain : il gère agenda, mails et la majorité des opérations CRUD sur le dashboard.

### Périmètre actuel d'Alfred sur les modèles

**Lecture** : tous les modèles sauf `PasswordEntry` (totalement exclu). Champs sensibles masqués côté lecture : `social_security_number`, `passport_number`, `national_id_number`, `driver_license_number`, `iban`, `bic`, `tax_id`, et les credentials de `MailAccount`.

**Écriture** :
- **Tier 1 (attributs explicites)** : `Event`, `Note`, `Task`, `BudgetEntry`, `Contact`, `LanguageSession`, `UsefulSite`, `Subscription`.
- **Tier 2 (toutes colonnes sauf id/timestamps)** : `PersonalProfile`, `HealthProfile`, `Property`, `Document`, `Project`, `Company`, `CrmProfile`, `CvExperience`, `CvFormation`, `CvInterest`, `CvSetting`, `CvSkill`, `Invoice`, `InvoiceItem`, `Quote`, `QuoteItem`.
- **Interdits** : `PasswordEntry`, `MailAccount`, `Language`.

### Implications pour toute évolution du code

1. **Nouveau modèle ajouté ?** Décide :
   - Faut-il l'exposer à la lecture ? → ajout dans `~/.claude/skills/life-dashboard/scripts/query.rb` (constante `ALLOWED`).
   - Faut-il l'exposer à l'écriture ? → ajout dans `~/.claude/skills/life-dashboard-write/scripts/write.rb` (constante `ALLOWED_WRITE`). Choix de format :
     - `:all` pour autoriser toutes les colonnes (Tier 2)
     - `{ create: [...], update: [...] }` pour un contrôle granulaire (Tier 1)
     - `{ exclude: [...] }` pour autoriser tout sauf certains champs
   - Met à jour `SKILL.md` correspondant + la section "Périmètre actuel" ci-dessus.

2. **Nouveau champ ajouté à un modèle Tier 1 ?** Pense à l'ajouter aux listes explicites `create:` / `update:`. Pour un modèle Tier 2 (`:all`), c'est automatique.

3. **Champ sensible ajouté ?** Pense à l'exclure côté skill lecture (`scripts/query.rb`, clé `exclude:` dans `ALLOWED`).

4. **Renommage d'un modèle ou d'un champ ?** Met à jour les deux skills, sinon Alfred plantera silencieusement.

5. **Nouvelle fonctionnalité métier scriptable** (génération PDF, envoi mail, génération automatique d'événement…) : pense à exposer un point d'entrée utilisable par Alfred (rake task, méthode de modèle, ou extension du script write).

→ Quand tu termines une feature, fais le tour de cette checklist avant de considérer le travail comme fini.

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
