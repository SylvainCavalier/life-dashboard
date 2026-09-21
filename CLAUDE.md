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
- **Transfert** — WeTransfer perso : upload direct vers le bucket OVH S3, lien de partage public temporaire, purge automatique après 3 jours
- **Downloader** — Téléchargement de vidéos depuis YouTube, Dailymotion, X/Twitter, Crowdbunker et tout site géré par yt-dlp, avec les métadonnées de source (auteur, date de publication, vues, plateforme) et une citation prête à coller (`VideoDownload#citation`, bouton « Citer ») (mp4 720p/1080p) ou de leur piste audio (mp3) via `yt-dlp` : fichier récupéré en local (`tmp/video_downloads/<id>/`) ou rangé sur le bucket OVH (Active Storage), classement par dossiers (`VideoFolder`, cloud uniquement) avec lecteur intégré (`/downloader/folders/:id`)
- **Projets** — Projets personnels classés par catégorie (`Project::CATEGORIES` : développement, musique, vidéo, jeu vidéo, sport, jeu de rôle, business...). Chaque projet a sa page (`/projects/:id`) : jauge, importance, compétences à apprendre (`ProjectSkill`), liens (`ProjectLink`), notes libres (`projects.notes`), to-do list (`Task` avec `project_id` ; `project_id` nul = to-do list générale du dashboard) et documents (`Document` avec `project_id`, domaine `projects`)
- **Voyages** — Organisation des voyages : rapport IA (OpenAI, recherche web) avec estimation des coûts, lieux, restaurants et itinéraire, planning visuel jour par jour, historique et carte SVG des pays visités

Architecture : Rails 8.0 monolith + Vue 3 SPA frontend. Single domain, Vue gère tout le UI, Rails sert d'API backend. Vite pour le build frontend.

## Rules

- **Do NOT run the dev server, tests, or linters** unless explicitly asked.
- Toujours demander confirmation avant de lancer `db:migrate` ou toute commande destructive.
- Le projet est en français (UI, commentaires) sauf le code (variables, méthodes en anglais).

## Subagent Alfred (intendant)

Ce dashboard est piloté à distance par le subagent global **Alfred** (`~/.claude/agents/alfred.md`), via les skills `life-dashboard` (lecture) et `life-dashboard-write` (écriture étendue). Alfred est l'intendant personnel de Sylvain : il gère agenda, mails et la majorité des opérations CRUD sur le dashboard.

### Périmètre actuel d'Alfred sur les modèles

**Lecture** : tous les modèles sauf `PasswordEntry` (totalement exclu), y compris `ProjectSkill`, `ProjectLink`, `Trip`, `TripItem`, `TripPlan` (rapport IA en JSON dans `content`), `VideoDownload` et `VideoFolder`. `FileTransfer` est exposé en lecture (Alfred peut retrouver un lien de partage encore actif). Champs sensibles masqués côté lecture : `social_security_number`, `passport_number`, `national_id_number`, `driver_license_number`, `iban`, `bic`, `tax_id`, et les credentials de `MailAccount`.

**Écriture** :
- **Tier 1 (attributs explicites)** : `Event`, `Note`, `Task` (dont `project_id`), `BudgetEntry`, `Contact`, `LanguageSession`, `UsefulSite`, `Subscription`, `Trip`, `TripItem`, `VideoFolder`.
- **Tier 2 (toutes colonnes sauf id/timestamps)** : `PersonalProfile`, `HealthProfile`, `Property`, `Document`, `Project`, `ProjectSkill`, `ProjectLink`, `Company`, `CrmProfile`, `CvExperience`, `CvFormation`, `CvInterest`, `CvSetting`, `CvSkill`, `Invoice`, `InvoiceItem`, `Quote`, `QuoteItem`.
- **Interdits** : `PasswordEntry`, `MailAccount`, `Language`, `FileTransfer` (la création exige un upload de fichier réel, impossible depuis un script). `TripPlan` est en lecture seule : le rapport IA se (re)génère via `bin/rails trips:plan[ID]` (asynchrone) ou `trips:plan_now[ID]` (synchrone). `VideoDownload` est en lecture seule : un téléchargement se lance via `bin/rails downloader:fetch URL=...` (asynchrone) ou `downloader:fetch_now` (synchrone), car créer l'enregistrement à la main n'enfilerait pas le job. Alfred utilise `fetch_now` : en développement, un job enfilé depuis une rake task ne s'exécute que si le serveur tourne (GoodJob en mode async). Le mode d'emploi du Downloader pour Alfred est dans `~/.claude/agents/alfred.md` (section Downloader) : à tenir à jour si les options de la rake task changent.

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

## Authentification et exposition publique

L'application est **mono-utilisateur** et destinee a etre hebergee sur un
domaine prive, volontairement non reference. Voir `DEPLOY.md` pour la procedure.

- **Tout est prive par defaut** : `ApplicationController` porte
  `before_action :authenticate_user!`. Un nouveau controleur est donc protege
  sans rien faire. Les seules exceptions, explicites, sont
  `TransfersController` (liens de partage `/t/:token`) et `Api::CalendarsController#feed`
  (flux ICS, authentifie par `CALENDAR_FEED_TOKEN`).
- **Ne jamais remettre `protect_from_forgery with: :null_session`** dans un
  controleur API : le SPA envoie deja le jeton CSRF via `plugins/axios.js`.
- **Pas d'inscription, pas de mot de passe oublie.** Le compte se cree avec
  `rails owner:bootstrap` (ou `db:seed` en dev) : identifiants de bootstrap
  connus, definis dans `User::BOOTSTRAP_EMAIL` / `BOOTSTRAP_PASSWORD`, poses
  **sans validation** puisque le mot de passe provisoire est plus court que le
  minimum impose ensuite.
- **Le mot de passe de bootstrap ne peut servir qu'une fois.** `User#must_change_password`
  fait rediriger toute l'application vers `/account/password` (403 JSON pour
  l'API) via `enforce_password_change!` dans `ApplicationController`. Deux
  controleurs s'en excluent, et c'est indispensable :
  `Users::PasswordChangesController` (sinon boucle de redirection) et
  `Users::SessionsController` (sinon la deconnexion elle-meme est interceptee et
  l'utilisateur est piege sur l'ecran). Ne pas retirer ces exclusions.
- Le changement de mot de passe passe par `/account/password`, une page ERB
  volontairement hors du SPA : un mot de passe n'a pas a transiter par axios ni
  a exister dans l'etat du client. Depannage :
  `owner:reset_password`, `owner:force_password_change`, `owner:unlock`.
- **Active Storage** : la lecture reste ouverte (les URL signees protegent les
  blobs, et les liens de partage en dependent), l'ecriture
  (`/rails/active_storage/direct_uploads`) est fermee par
  `config/initializers/active_storage_auth.rb`.
- **Coffre-fort** : `GET /api/password_entries` ne renvoie jamais les mots de
  passe. La revelation se fait entree par entree via
  `GET /api/password_entries/:id/reveal`, tracee dans les logs et limitee par
  Rack::Attack. Ne pas revenir en arriere.
- **Anti-indexation** : en-tete `X-Robots-Tag` sur chaque reponse
  (`config/application.rb`), `public/robots.txt` en `Disallow: /`, balises
  `<meta name="robots">` dans les trois layouts, et surtout `config.hosts`
  limite a `APP_HOST` en production — l'app renvoie 403 sur l'hote
  `*.herokuapp.com`. Toute nouvelle page publique doit conserver ces garanties.
- **`referrer_policy` doit rester `same-origin`**, jamais `no-referrer` : avec
  cette derniere, le navigateur envoie `Origin: null` y compris sur les
  formulaires same-origin et Rails rejette la connexion
  (`InvalidAuthenticityToken`). La protection CSRF etant desactivee en test
  (`config.action_controller.allow_forgery_protection = false`), aucun test
  d'integration ne peut attraper ca : c'est l'assertion sur l'en-tete
  `Referrer-Policy` dans `access_control_test.rb` qui sert de garde-fou.
- **Anti-indexation** : l'en-tete est pose par `RobotsTagMiddleware`
  (`lib/middleware/`), insere en position 0 de la pile. Ne pas le remplacer par
  `action_dispatch.default_headers` : ceux-ci ne couvrent pas les reponses
  generees par Warden (la redirection vers la connexion, c'est-a-dire
  exactement ce qu'un crawler recoit).
- **Export PDF du CV** : Grover a besoin d'un Chrome headless, absent d'Heroku
  sans buildpack. En cas d'echec, `Api::CvsController#export_pdf` repond 503 avec
  `{"fallback": "browser_print"}` et `CVPreviewModal.vue` bascule sur
  l'impression navigateur avec le meme document. Garder ce repli fonctionnel.
- `test/integration/access_control_test.rb` et `password_change_test.rb`
  verrouillent tout ce qui precede : un controleur ajoute sans authentification
  fait echouer la suite.

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

### Stockage OVH (Object Storage S3)
```bash
rake ovh:cors:show                                   # Config CORS actuelle du bucket
rake ovh:cors:setup ORIGINS=https://mon-dashboard.fr # Autorise le direct upload depuis ce domaine
```
Le module Transfert utilise le **direct upload** Active Storage : le navigateur envoie le
fichier en PUT directement sur le bucket. Sans CORS configuré, l'upload échoue côté
navigateur. L'origine du bucket est aussi ajoutée à `connect_src` dans la CSP
(`config/initializers/secure_headers.rb`), via `OVH_S3_ENDPOINT`.

### Downloader (yt-dlp)
```bash
bin/rails downloader:check                                   # yt-dlp et ffmpeg operationnels ?
bin/rails downloader:update                                  # met a jour yt-dlp (a faire quand YouTube casse)
bin/rails downloader:fetch URL="https://..." FORMAT=mp3      # enfile un telechargement (GoodJob)
bin/rails downloader:fetch_now URL="https://..." STORAGE=cloud FOLDER=nom  # telecharge immediatement (debogage, Alfred)
```
Options : `FORMAT` (mp4 | mp3), `QUALITY` (original | 720p), `STORAGE` (local par defaut | cloud), `FOLDER`.
`VideoDownload.enqueue!` est le point d'entree unique (API et rake) ; `VideoDownloadJob` appelle
`VideoDownloads::YtDlpService` puis, en cloud, attache le fichier via Active Storage avec une cle
lisible (`video_downloads/<dossier>/<id>-<nom>`). La table `video_downloads` fait foi pour l'etat
du job : l'interface la sonde toutes les 3 s tant qu'un telechargement est actif.
Sites : rien n'est specifique a YouTube ; YouTube, Dailymotion, X/Twitter et Crowdbunker (extracteur natif
de yt-dlp) sont valides de bout en bout. Les champs de source varient selon les sites (Crowdbunker : ni
heure de publication ni URL d'auteur) : tous sont optionnels, `published_at` retombe sur `upload_date`.
Les erreurs yt-dlp courantes sont completees d'une piste en francais (`YtDlpService::HINTS`).
Le choix du format passe par un **tri** (`-S vcodec:h264,res:1080,acodec:aac`) et non par un filtre
`height<=` : le filtre degradait les videos verticales (1080x1920 -> 480x854). `--playlist-items 1`
garantit une seule video (un tweet peut en contenir plusieurs ; `/video/2` en fin d'URL vise la 2e).
X/Twitter exige souvent d'etre connecte : ce sont les cookies Chrome (`YT_DLP_COOKIES_FROM_BROWSER`)
qui le permettent. Le badge de plateforme de l'historique est deduit de l'URL cote front (`sourceOf`).
Binaires requis : `yt-dlp` (plus un runtime JS, `deno`, indispensable pour YouTube) et `ffmpeg`. Sur la
machine de Sylvain ils vivent dans `~/.local/bin` (binaire officiel autonome de yt-dlp, build statique
evermeet.cx de ffmpeg/ffprobe) et non dans Homebrew : sous macOS 14, Homebrew n'a plus de bottles et
recompile llvm/rust/deno depuis les sources pendant des heures. Ne pas lancer `brew upgrade yt-dlp`. Variables : `YT_DLP_BIN`,
`YT_DLP_COOKIES_FROM_BROWSER` (defaut `chrome` en developpement, vide ailleurs). Sans ces binaires
(Heroku sans buildpack), `GET /api/video_downloads/availability` le signale et la page affiche un
bandeau ; voir `DEPLOY.md`. Ne pas nommer une action de controleur `status` : cela ecrase
`ActionController::Metal#status`. Le bucket OVH est en `media_src` dans la CSP pour le lecteur.

### Voyages (rapport IA)
```bash
bin/rails trips:plan[ID]       # enfile la generation du rapport IA d'un voyage (GoodJob)
bin/rails trips:plan_now[ID]   # genere immediatement, sans GoodJob (debogage, Alfred)
```
Le rapport est produit par `Trips::PlanGenerationService` (OpenAI Responses API, outil
`web_search`, sortie structuree `Trips::TripPlanSchema`) dans `TripPlanJob`, et stocke
en jsonb dans `trip_plans.content`. Variables : `OPENAI_API_KEY` (obligatoire),
`OPENAI_TRIP_MODEL` (defaut `gpt-5.6-sol`). Un rapport coute environ 0,3 a 1 EUR.
La carte du monde de l'index vient de `@svg-maps/world` (CC BY 4.0) ; les codes pays
sont les ids de cette carte (ISO alpha-2 minuscule).

### Deploiement (Heroku)
```bash
git push heroku master                    # migrations jouees par le `release:` du Procfile
heroku run rails owner:create             # cree le compte unique (premiere mise en ligne)
heroku logs --tail
```
Procedure complete, variables d'environnement et migration des donnees : `DEPLOY.md`.

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
