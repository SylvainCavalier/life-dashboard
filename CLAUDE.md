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
- **Downloader** — Téléchargement de vidéos depuis YouTube, Dailymotion, X/Twitter, Crowdbunker et tout site géré par yt-dlp, en entier ou sur un extrait (de 0:34 à 0:47), avec les métadonnées de source (auteur, date de publication, vues, plateforme) et une citation prête à coller (`VideoDownload#citation`, bouton « Citer ») (mp4 720p/1080p) ou de leur piste audio (mp3) via `yt-dlp` : fichier récupéré en local (`tmp/video_downloads/<id>/`) ou rangé sur le bucket OVH (Active Storage), classement par dossiers (`VideoFolder`, cloud uniquement) avec lecteur intégré (`/downloader/folders/:id`)
- **Projets** — Projets personnels classés par catégorie (`Project::CATEGORIES` : développement, musique, vidéo, jeu vidéo, sport, jeu de rôle, business...). Chaque projet a sa page (`/projects/:id`) : jauge, importance, compétences à apprendre (`ProjectSkill`), liens (`ProjectLink`), notes libres (`projects.notes`), to-do list (`Task` avec `project_id` ; `project_id` nul = to-do list générale du dashboard) et documents (`Document` avec `project_id`, domaine `projects`)
- **Sentinelle** — Veille hebdomadaire personnalisée, un onglet par domaine (`/sentinelle/:domaine`) : **Droit du travail** (Judilibre, Légifrance, Village de la Justice) et **Désinformation** (flux RSS + recherche web Tavily sur une liste blanche de sites). Chaque semaine (lundi → dimanche) se lance à la main : collecte, tri déterministe, résumé IA par document puis synthèse de la semaine (`/sentinelle/:domaine/:lundi`). Les domaines sont isolés (registre `Sentinel::Domains`) : en ajouter un ne touche pas aux autres
- **Alfred (chat)** — L'intendant installe dans le dashboard : icone de chat en bas a droite de toutes les pages (`AlfredWidget.vue`, monte dans `App.vue`). Agent a outils (Claude) adosse a un corpus RAG (pgvector + mistral-embed) qui couvre les donnees du dashboard ET le texte des documents (OCR Mistral pour les scans). Lit tout sauf les mots de passe, n'ecrit que sur confirmation explicite dans le chat. Voir « Alfred dans le dashboard »
- **Voyages** — Organisation des voyages : rapport IA (OpenAI, recherche web) avec estimation des coûts, lieux, restaurants et itinéraire, planning visuel jour par jour, historique et carte SVG des pays visités

Architecture : Rails 8.0 monolith + Vue 3 SPA frontend. Single domain, Vue gère tout le UI, Rails sert d'API backend. Vite pour le build frontend.

## Rules

- **Do NOT run the dev server, tests, or linters** unless explicitly asked.
- Toujours demander confirmation avant de lancer `db:migrate` ou toute commande destructive.
- Le projet est en français (UI, commentaires) sauf le code (variables, méthodes en anglais).

## Subagent Alfred (intendant)

Ce dashboard est piloté à distance par le subagent global **Alfred** (`~/.claude/agents/alfred.md`), via les skills `life-dashboard` (lecture) et `life-dashboard-write` (écriture étendue). Alfred est l'intendant personnel de Sylvain : il gère agenda, mails et la majorité des opérations CRUD sur le dashboard.

### Périmètre actuel d'Alfred sur les modèles

**Lecture** : tous les modèles sauf `PasswordEntry` (totalement exclu), y compris `ProjectSkill`, `ProjectLink`, `Trip`, `TripItem`, `TripPlan` (rapport IA en JSON dans `content`), `VideoDownload`, `VideoFolder`, `SentinelSource`, `SentinelWeek` (synthèse hebdo en JSON dans `digest`) et `SentinelDocument` (sans `raw_content` ni `raw_metadata`, trop lourds). `FileTransfer` est exposé en lecture (Alfred peut retrouver un lien de partage encore actif). Champs sensibles masqués côté lecture : `social_security_number`, `passport_number`, `national_id_number`, `driver_license_number`, `iban`, `bic`, `tax_id`, et les credentials de `MailAccount`.

**Écriture** :
- **Tier 1 (attributs explicites)** : `Event`, `Note`, `Task` (dont `project_id`), `BudgetEntry`, `Contact`, `LanguageSession`, `UsefulSite`, `Subscription`, `Trip`, `TripItem`, `VideoFolder`, `SentinelSource` (sans `adapter`, qui désigne du code).
- **Tier 2 (toutes colonnes sauf id/timestamps)** : `PersonalProfile`, `HealthProfile`, `Property`, `Document`, `Project`, `ProjectSkill`, `ProjectLink`, `Company`, `CrmProfile`, `CvExperience`, `CvFormation`, `CvInterest`, `CvSetting`, `CvSkill`, `Invoice`, `InvoiceItem`, `Quote`, `QuoteItem`.
- **Interdits** : `PasswordEntry`, `MailAccount`, `Language`, `FileTransfer` (la création exige un upload de fichier réel, impossible depuis un script). `TripPlan` est en lecture seule : le rapport IA se (re)génère via `bin/rails trips:plan[ID]` (asynchrone) ou `trips:plan_now[ID]` (synchrone). `VideoDownload` est en lecture seule : un téléchargement se lance via `bin/rails downloader:fetch URL=...` (asynchrone) ou `downloader:fetch_now` (synchrone), car créer l'enregistrement à la main n'enfilerait pas le job. Alfred utilise `fetch_now` : en développement, un job enfilé depuis une rake task ne s'exécute que si le serveur tourne (GoodJob en mode async). `SentinelWeek` et `SentinelDocument` sont en lecture seule : une veille se lance via `bin/rails sentinel:run DOMAIN=... MONDAY=...` (asynchrone) ou `sentinel:run_now` (synchrone, celui qu'utilise Alfred, pour la même raison que `fetch_now`). Le mode d'emploi du Downloader pour Alfred est dans `~/.claude/agents/alfred.md` (section Downloader) : à tenir à jour si les options de la rake task changent.

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

4. **Renommage d'un modèle ou d'un champ ?** Met à jour les deux skills, sinon Alfred plantera silencieusement. Même chose pour l'Alfred du dashboard : `Alfred::DataAccess` (`READABLE` / `WRITABLE`) et `Alfred::Corpus::REGISTRY`.

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
Options : `FORMAT` (mp4 | mp3), `QUALITY` (original | 720p), `STORAGE` (local par defaut | cloud), `FOLDER`,
`CLIP_START` / `CLIP_END` (extrait ; timecodes `0:34`, `1:02:03` ou secondes ; les deux ou aucun).
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
Extraits : `clip_start` / `clip_end` (secondes en base, timecodes acceptes par les setters du modele) passent
par `--download-sections` : seul le passage est telecharge. `--force-keyframes-at-cuts` est **obligatoire** :
sans lui la coupe tombe sur l'image cle precedente et le debut de l'extrait n'est pas decodable (mesure :
1re image cle a 5,7 s sur 13 s), pour un gain de temps nul. `duration` devient celle de l'extrait, le nom du
fichier porte `(0m34s-0m47s)`, la citation ajoute « extrait de 0:34 a 0:47 » et, sur YouTube, `&t=34s`.
Dans le modele et le service, ecrire `Kernel.format` : `format` y est l'attribut mp4/mp3.
Binaires requis : `yt-dlp` (plus un runtime JS, `deno`, indispensable pour YouTube) et `ffmpeg`. Sur la
machine de Sylvain ils vivent dans `~/.local/bin` (binaire officiel autonome de yt-dlp, build statique
evermeet.cx de ffmpeg/ffprobe) et non dans Homebrew : sous macOS 14, Homebrew n'a plus de bottles et
recompile llvm/rust/deno depuis les sources pendant des heures. Ne pas lancer `brew upgrade yt-dlp`. Variables : `YT_DLP_BIN`,
`YT_DLP_COOKIES_FROM_BROWSER` (defaut `chrome` en developpement, vide ailleurs). Sans ces binaires
(Heroku sans buildpack), `GET /api/video_downloads/availability` le signale et la page affiche un
bandeau ; voir `DEPLOY.md`. Ne pas nommer une action de controleur `status` : cela ecrase
`ActionController::Metal#status`. Le bucket OVH est en `media_src` dans la CSP pour le lecteur.

### Sentinelle (veille hebdomadaire)
```bash
bin/rails sentinel:check                                          # cles API presentes ? sources en panne ?
bin/rails sentinel:seed_sources DOMAIN=all                        # installe les sources par defaut manquantes
bin/rails sentinel:run DOMAIN=droit_travail MONDAY=2026-09-14     # enfile la veille d'une semaine (GoodJob)
bin/rails sentinel:run_now DOMAIN=all                             # traite immediatement (debogage, Alfred)
```
`DOMAIN` : `droit_travail`, `desinformation` ou `all`. `MONDAY` : lundi de la semaine, par defaut la derniere
semaine ecoulee. Aucun cron : le declenchement est volontairement manuel (bouton de la page ou rake task).

**Un domaine = une classe** de `app/services/sentinel/domains/` (sous-classe de `Sentinel::Domains::Base`), inscrite
dans `Sentinel::Domains::REGISTRY`. Elle porte tout ce qui est propre au domaine : sources par defaut, types de
documents, categories, classifieur deterministe, role et echelle d'importance des prompts, requetes de recherche web.
Le pipeline est generique et ne connait aucun domaine. Pour **ajouter un domaine** : ecrire la classe, l'inscrire
au registre, c'est tout (l'onglet, les sources par defaut et la rake task suivent). Les tables
(`sentinel_sources`, `sentinel_weeks`, `sentinel_documents`) sont communes mais toute lecture est bornee par
`domain` : deux domaines ne se melangent jamais, ni a la collecte ni dans les syntheses.

`SentinelWeek.run!` est le point d'entree unique (API et rake) ; `SentinelWeekJob` enchaine trois etapes, chacune
**reprenable** (relancer une semaine ne repaie que ce qui manque) :
1. `Sentinel::Collector` : chaque source active est interrogee par tous ses canaux (`adapter` = API ou scraper
   dedie, `feed_url` = RSS/Atom, `web_search` = Tavily restreint a son nom de domaine), dedoublonnage sur
   `[source, external_id]` (URL normalisee par `Sentinel::UrlNormalizer` pour les articles), puis tri par
   `domain.classify` AVANT tout appel au modele. Un document hors champ est conserve sans son texte (tri auditable).
   Une source en panne ne fait pas echouer la semaine : erreur notee sur la source (`last_error`) et remontee dans
   `sentinel_weeks.warnings`.
2. `Sentinel::DocumentSummarizer` (sortie structuree `Sentinel::DocumentSummarySchema`), 4 appels en parallele,
   plafond de 80 resumes par lancement. Service pur : c'est le job qui ecrit en base.
3. `Sentinel::DigestGenerator` (`Sentinel::DigestSchema`) : la synthese ne recoit QUE les resumes, jamais les textes
   bruts, et tout `document_id` absent de la liste envoyee est ecarte (garde anti-hallucination). Ne pas revenir la-dessus.

Une semaine va toujours du lundi au dimanche, heure de Paris (`SentinelWeek.window`). La table `sentinel_weeks`
fait foi pour l'etat du job (`status`, `step`, `progress_*`) : l'interface la sonde toutes les 3 s.
Variables : `OPENAI_API_KEY` (obligatoire), `OPENAI_SENTINEL_MODEL` (synthese, defaut `gpt-5.6-sol`),
`OPENAI_SENTINEL_SUMMARY_MODEL` (resumes, le gros du volume : y mettre un modele moins cher ; defaut = le precedent),
`PISTE_CLIENT_ID` / `PISTE_CLIENT_SECRET` (Judilibre et Legifrance, compte piste.gouv.fr abonne aux deux API),
`TAVILY_API_KEY` (recherche web, facultative : sans elle seuls les flux RSS sont collectes).
Pieges connus : Legifrance n'a aucun filtre thematique (on ramene tout le JO de la semaine, un appel `/consult` par
texte, c'est le classifieur NOR + motifs qui trie) ; Judilibre se lit par `/export` et non `/search` ; le scraper
Village de la Justice depend des classes CSS du site et leve `LayoutChanged` s'il ne trouve plus rien (l'URL de la
rubrique se regle sur la source) ; Tavily ne sait ni filtrer par dates avec `include_domains` ni dater ses resultats
hors grands medias, d'ou la datation par les balises meta de la page (`Sentinel::ArticleText`) et l'abandon de la
recherche web pour une semaine de plus d'un mois (details en tete de `Sentinel::TavilySearch`).

### Alfred dans le dashboard (agent IA + corpus RAG)
```bash
bin/rails alfred:check                          # cles API, pgvector, etat du corpus, indexations en echec
bin/rails alfred:index                          # indexe tout le corpus (MODEL=Document,Note ; FORCE=1 = tout recalculer, OCR compris)
bin/rails alfred:search Q="bail appartement"    # teste la recherche seule (scores, cosine brut)
bin/rails alfred:ask Q="Mes rendez-vous ?"      # pose une question sans l'interface (outils appeles, tokens, latence)
```
A ne pas confondre avec le **subagent Alfred local** (section precedente), qui tourne dans Claude Code sur le Mac avec ses
MCP (Gmail, Agenda...). Celui-ci vit DANS l'application et n'a que les outils de `Alfred::Tools`. Meme personnage, meme
perimetre de donnees ; `Alfred::Prompt` est la transposition de `~/.claude/agents/alfred.md`.

**Deux fournisseurs, deux roles.** Embeddings et OCR : Mistral (`Embeddings.default`, interchangeable par
`EMBEDDING_PROVIDER`, cache `embedding_caches` par `(provider, model, SHA256)`). Agent : Claude via le SDK `anthropic`
(`Alfred::Agent`, specifique a l'API Anthropic par construction : blocs tool_use, reflexion adaptative). Anthropic n'a
pas d'API d'embeddings, le duo est donc structurel. Variables : `ANTHROPIC_API_KEY`, `MISTRAL_API_KEY` (obligatoires),
`ALFRED_MODEL` (defaut `claude-sonnet-5`), `ALFRED_EFFORT` (`medium`), `ALFRED_HYBRID` (`1`), `ALFRED_MIN_COSINE` (`0.30`),
`ALFRED_OCR` (`1`), `ALFRED_INDEXING` (`1`, `0` en test), `ALFRED_HISTORY_MESSAGES` (`16`). Ne pas envoyer `temperature`
ni `budget_tokens` a Sonnet 5 : l'API repond 400.

**Corpus** (`Alfred::Corpus`). `REGISTRY` liste les modeles indexes et comment les presenter ; `install_hooks!`
(initializer `alfred.rb`, dans un `to_prepare`) leur pose des `after_commit` qui enfilent `AlfredIndexJob`. Un modele
enfant (`InvoiceItem`, `ProjectSkill`...) declare `parent:` : il n'a pas de fiche, il fait reindexer son parent, qui
l'inclut via `children:`. **Ajouter un modele au corpus = une entree dans `REGISTRY`**, puis `rails alfred:index MODEL=...`.
`Indexer` produit deux sortes de passages (`alfred_chunks.kind`) : `record` (la fiche, rendue par `RecordRenderer`) et
`file` (texte du fichier joint de `Document`). Chaque moitie a son empreinte sur `alfred_index_entries` : modifier les
notes d'un document ne repaie pas son OCR. `TextExtractor` : pdf-reader d'abord, OCR Mistral si le PDF ramene moins de
80 caracteres par page (scan) ou si c'est une image.
- Les attributs `encrypts` (IBAN, numero de securite sociale, passeport...) sont **ecartes du corpus** automatiquement
  (`klass.encrypted_attributes`) pour ne pas les recopier en clair dans `alfred_chunks` ; Alfred les lit a la demande
  par `query_records`. En revanche le texte OCR d'un document (un scan de passeport) est bien en clair dans
  `alfred_chunks.content` : c'est voulu (decision de Sylvain), et c'est le meme niveau d'exposition que le fichier sur le bucket.
- `alfred_messages.content` et `alfred_actions.payload` sont chiffres (`encrypts`) : une reponse peut citer un IBAN.
  Consequence : `update_columns` ne chiffre pas, d'ou `Agent#encrypted` pour le texte diffuse au fil de l'eau.
- **Jamais dans le corpus ni dans `DataAccess`** : `PasswordEntry`, les identifiants de `MailAccount`, `User`. C'est la seule
  limite de lecture voulue par Sylvain (les champs sensibles masques pour l'Alfred local sont lisibles ici).
  `indexer_test.rb` et `tools_test.rb` verrouillent ce point.

**Recherche** (`Alfred::Corpus::Search`), hybride par defaut (vectoriel 0.7 + lexical 0.3 : les noms propres comptent
dans des donnees personnelles). Trois invariants a ne pas defaire, couverts par `search_test.rb` : (1) le plancher
`MIN_COSINE_SIMILARITY` porte sur le **cosine brut** et rien en dessous n'atteint le modele ; (2) le bras lexical
(tsvector `french` sur `content_fold`, accents plies en Ruby des deux cotes par `Alfred::AccentFolding`) **reclasse sans
jamais elargir** l'ensemble eligible ; (3) la fraicheur (`Recency`, plancher 0.9) ne fait qu'ordonner et `ensure_anchor`
garantit que le meilleur cosine brut survit a la coupe. S'y ajoutent un plafond de 3 passages par enregistrement et une
place garantie par type de source (`diversify`). L'index HNSW est en `vector_cosine_ops` : il DOIT correspondre a la
distance des requetes, sinon il est ignore en silence. `vector(1024)` = `Embeddings::DIMENSIONS` = mistral-embed :
changer de modele d'embedding impose une migration de la colonne et un `alfred:index FORCE=1`.

**Agent et outils.** `POST /api/alfred_conversations/:id/message` cree le message et une reponse `pending`, puis
`AlfredReplyJob` fait tourner `Alfred::Agent` : boucle d'outils (12 tours max), texte diffuse dans
`alfred_messages.content` toutes les 350 ms. La table fait foi, l'interface la sonde toutes les secondes (pas de SSE ni
d'ActionCable : meme patron que Downloader et Sentinelle, et une reponse survit a un rechargement de page). Outils :
`search_corpus`, `query_records` (lecture structuree, `DataAccess::READABLE`), `describe_models`, `propose_write`.
L'historique rejoue ne contient que du texte (questions, reponses, notes `[Systeme]`), jamais les resultats d'outils
des tours passes : Alfred relit la base. Le prompt stable est mis en cache cote API ; la date et les consignes
particulieres (`AlfredSetting`, editables dans le chat) vont dans un second bloc APRES le point de cache : ne rien
mettre de variable dans `Prompt.stable_text`.

**Ecritures : le modele ne peut que proposer.** `propose_write` valide (liste blanche `DataAccess::WRITABLE`, memes
tiers que la skill write, `record.valid?`) et cree une `AlfredAction` `proposed`, rien d'autre. Le chat affiche une carte
avant/apres ; seul `POST /api/alfred_actions/:id/confirm` (`Alfred::ActionExecutor`) ecrit, apres avoir tout reverifie
et refuse si l'enregistrement a change depuis la proposition. Pas de suppression. Une note `event` consigne le
resultat dans la conversation, c'est par elle que le modele sait au tour suivant que l'ecriture a eu lieu. Ne jamais
donner au modele un outil qui ecrit directement. `DataAccess` double les listes blanches des skills locales
(`query.rb` / `write.rb`) : **un modele ajoute ou renomme se met a jour aux trois endroits** (voir la checklist plus haut).
Les tables d'Alfred (`alfred_*`, `embedding_caches`) ne sont volontairement exposees a aucune des deux skills.

Pas encore dans l'Alfred du dashboard : mails, Google Agenda, Downloader, Sentinelle, Voyages (les points d'entree
existent : `VideoDownload.enqueue!`, `SentinelWeek.run!`, `Trip#generate_plan!` ; les brancher = un outil de plus dans
`Alfred::Tools::ALL`, avec confirmation pour ce qui coute).

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

**Backend:** Rails 8.0, PostgreSQL (+ pgvector), anthropic, neighbor, Devise, Pundit, GoodJob, Pagy 43, PaperTrail
**Frontend:** Vue 3.5, Vite 5, Pinia, Vue Router, Axios, Tailwind CSS 3.4
**Requires:** Ruby 3.3.5, Node 20.x
