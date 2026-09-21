# Historique – Life Dashboard

Journal de bord des sessions de travail, par ordre antéchronologique (le plus récent en haut).
Les nouvelles entrées sont ajoutées par la commande `/historyupdate` en fin de session.

---

### 2026-09-21 — Module Downloader (yt-dlp) multi-sites
- [feat] Nouveau module Downloader (`/downloader`), repris du projet séparé `video-downloader` : on colle l'URL d'une vidéo, on choisit mp4 (jusqu'à 1080p ou 720p) ou mp3, et le fichier est soit gardé en local (`tmp/video_downloads/<id>/`, récupéré par le bouton « Récupérer »), soit rangé sur le bucket OVH ; historique avec suivi en direct de l'état (en attente, en cours, terminé, échec) et tuile sur le dashboard
- [feat] Dossiers de classement pour les téléchargements cloud (création, renommage, suppression sans perte des fichiers) et page dossier `/downloader/folders/:id` avec grille de vignettes et lecteur vidéo/audio intégré
- [feat] Sites pris en charge et validés par de vrais téléchargements : YouTube, Dailymotion, X/Twitter et Crowdbunker (tous gérés nativement par yt-dlp, comme TikTok, Vimeo, Rumble, Odysee… non testés) ; badge de plateforme dans l'historique ; pour un tweet contenant plusieurs vidéos, seule la première est prise, `/video/2` en fin d'URL vise la suivante
- [feat] Métadonnées de source enregistrées à chaque téléchargement (plateforme, URL canonique, auteur/chaîne et son lien, date de publication, nombre de vues relevé au moment du téléchargement) et bouton « Citer » qui copie une référence prête à publier : « Titre », Auteur (Plateforme), publié le …, URL (consulté le …) — pensé pour citer les sources des vidéos de débunkage
- [fix] Les vidéos verticales n'étaient téléchargées qu'en 480×854 : l'ancien sélecteur (hérité de `video-downloader`) plafonnait la hauteur à 1080 ; remplacé par un tri yt-dlp sur la plus petite dimension (`-S vcodec:h264,res:1080,acodec:aac`), qui garde la priorité H.264/AAC pour la compatibilité After Effects / Premiere
- [improve] Les erreurs yt-dlp courantes sont complétées d'une « Piste : … » en français (direct programmé jamais enregistré, site non géré, connexion au site requise, extraction cassée par un changement du site, vidéo supprimée), et la page affiche un bandeau quand yt-dlp ou ffmpeg sont absents ou ne démarrent pas (la sonde lance réellement les binaires)
- [refactor] Par rapport à `video-downloader` : modèles renommés `VideoDownload` / `VideoFolder`, sans `user_id` ni Pundit (app mono-utilisateur) ; stockage cloud via Active Storage (service `ovh`) avec une clé lisible `video_downloads/<dossier>/<id>-<nom>` au lieu du client S3 brut ; `VideoDownload.enqueue!` comme point d'entrée unique (API et rake) ; un échec du job est consigné sur l'enregistrement sans être relevé
- [db] Nouvelles tables `video_folders` (nom unique sans tenir compte de la casse) et `video_downloads`, puis colonnes de source `platform`, `canonical_url`, `uploader`, `uploader_handle`, `uploader_url`, `published_at`, `view_count` ; migrations jouées en développement
- [security] Bucket OVH ajouté à `media_src` dans la CSP (le lecteur suit une redirection vers l'URL pré-signée) ; URL restreinte à http(s) et passée à yt-dlp après `--` pour exclure toute injection d'option ; `/api/video_downloads`, `/availability` et `/api/video_folders` ajoutés au test de contrôle d'accès
- [infra] Sur le Mac de développement, yt-dlp (binaire officiel autonome 2026.08.19, somme SHA-256 vérifiée) et ffmpeg/ffprobe 9.0.2 (build statique evermeet.cx, Intel via Rosetta) sont installés dans `~/.local/bin` et non via Homebrew : sous macOS 14.5 Homebrew n'a plus de bottles et recompile llvm/rust/deno pendant des heures (`brew upgrade yt-dlp` à proscrire tant que macOS n'est pas mis à jour) ; le ffmpeg Homebrew reste cassé (libx265 manquante) mais masqué. Limites en production documentées dans `DEPLOY.md` (buildpacks nécessaires, IP de datacenter bloquées par YouTube, disque éphémère)
- [chore] Points d'entrée scriptables `downloader:fetch` (GoodJob), `downloader:fetch_now` (synchrone, affiche le chemin et la ligne `Source : …`), `downloader:check` et `downloader:update` (`yt-dlp -U`, à lancer quand un site casse l'extraction) ; stockage `local` par défaut comme dans l'interface
- [chore] Alfred branché sur le module : `VideoDownload` et `VideoFolder` en lecture, `VideoFolder` en écriture, téléchargement via `downloader:fetch_now` uniquement (un job enfilé depuis une rake task ne s'exécute que si le serveur tourne) ; section Downloader ajoutée à `~/.claude/agents/alfred.md` (ne jamais appeler yt-dlp directement, copie dans `~/Downloads`, transmission de la citation) après qu'un premier test a montré qu'il contournait le module ; validé dans une session neuve
- [chore] Tests écrits mais non lancés : modèle, job, service yt-dlp (arguments, tri des formats, métadonnées de source, pistes d'erreur), intégration API et contrôle d'accès ; helper `VideoDownloadStorageHelper` pour isoler les fichiers locaux entre workers parallèles. Rien n'était commité à la fin de la session

### 2026-09-21 — Projets multi-catégories et fiche projet
- [feat] Catégories de projets (Développement, Musique, Vidéo, Jeu vidéo, Sport, Jeu de rôle, Business, Écriture, Apprentissage, Autre) : le module Projets n'est plus réservé au développement web ; onglets de catégorie avec compteurs sur `/projects` (seules les catégories utilisées s'affichent), en plus de la recherche et du filtre par statut
- [feat] Page détail par projet (`/projects/:id`) : en-tête avec jauge modifiable directement, importance, statut, et quatre blocs — compétences à apprendre, liens, documents, notes personnelles libres enregistrées à la sortie du champ
- [feat] Compétences à apprendre par projet (ex. Blender, Unreal Engine) avec trois statuts (à apprendre, en cours, acquise) qu'on fait défiler d'un clic sur le badge
- [feat] To-do list propre à chaque projet, identique à celle du dashboard (priorité en étoiles, échéance, édition en ligne) ; bouton pour aligner la jauge d'avancement sur le pourcentage de tâches terminées
- [feat] Liens et documents rattachés à un projet : liens avec titre déduit du nom de domaine s'il est omis, documents uploadés depuis la fiche projet et visibles aussi dans le module Documents (nouveau domaine « Projets »)
- [improve] Les cartes de l'index des projets sont cliquables et affichent des compteurs (tâches faites/total, compétences acquises/total, liens, documents) ; créer un projet ouvre directement sa fiche ; le champ GitHub n'apparaît que pour les catégories Développement et Jeu vidéo, et « Lien du site » devient « Lien principal »
- [refactor] `TodoList.vue` accepte un `projectId` et un titre : sans `projectId` c'est la to-do list générale, qui ne liste plus que les tâches sans projet (`GET /api/tasks` sans paramètre, `?project_id=` pour celles d'un projet) ; formulaire projet extrait dans `components/projects/ProjectForm.vue` et constantes du module dans `composables/useProjects.js`
- [db] Colonne `projects.category` (défaut `developpement`, les projets existants y restent), nouvelles tables `project_skills` et `project_links`, colonne `project_id` nullable sur `tasks` et `documents` ; supprimer un projet supprime ses tâches, compétences, liens et documents. Migrations générées mais pas encore jouées à la fin de la session
- [chore] `ProjectSkill` et `ProjectLink` exposés au subagent Alfred en lecture et en écriture (Tier 2), `project_id` ajouté aux attributs autorisés de `Task` ; `SKILL.md` des deux skills et CLAUDE.md mis à jour
- [chore] Tests écrits mais non lancés (migrations en attente) : modèle `Project`, intégration `projects_test.rb` (catégories, compétences, liens, séparation des tâches par projet, document rattaché) et `/api/projects` + `/api/tasks` ajoutés au test de contrôle d'accès

### 2026-09-15 — Module Voyages avec rapport IA
- [feat] Nouveau module Voyages (`/trips`) : création d'un voyage (destination, pays ISO, dates, voyageurs, ville de départ, statut envisagé/confirmé/annulé, notes), page détail `/trips/:id`, historique des voyages passés et tuile sur le dashboard
- [feat] Rapport IA par voyage, lancé d'un clic et sauvegardé en base : estimation des coûts en euros (vols, hébergement, nourriture, activités, total et hypothèses), présentation et histoire de la destination, infos pratiques, réglementations et interdictions, lieux à visiter avec prix et lien de réservation, restaurants de cuisine locale, itinéraire jour par jour et sources consultées
- [feat] Planning visuel du voyage : une carte par jour où l'on ajoute hôtels, restaurants, visites et transports avec heure, coût, notes et lien cliquable ; boutons « + Planning » sur chaque lieu, restaurant ou journée suggérée par le rapport IA
- [feat] Carte du monde SVG sur l'index colorisant les pays visités (voyages passés non annulés) et les pays prévus, avec sélection d'un pays par clic pour pré-remplir le formulaire
- [api] Intégration OpenAI (gem officielle `openai`, API Responses) avec l'outil de recherche web et une sortie JSON structurée par schéma strict (`Trips::TripPlanSchema`) ; modèle `gpt-5.6-sol` par défaut, surchargeable via `OPENAI_TRIP_MODEL` ; premier rapport réel validé (Lisbonne, 3 min, ~19 sources)
- [improve] Génération asynchrone via GoodJob avec polling côté SPA, verrou anti double-clic, relance d'un job bloqué au-delà de 15 minutes, conservation de l'ancien rapport en cas d'échec et signalement d'un rapport obsolète quand le voyage change
- [db] Nouvelles tables `trips`, `trip_plans` (rapport IA en jsonb, une ligne par voyage) et `trip_items` (planning) ; items hors des dates du voyage conservés et affichés dans un groupe « Hors dates »
- [chore] Modèles Trip, TripItem et TripPlan exposés au subagent Alfred (lecture, écriture Tier 1 pour Trip/TripItem) et tâches `trips:plan[ID]` / `trips:plan_now[ID]` comme points d'entrée scriptables ; CLAUDE.md et DEPLOY.md mis à jour
- [chore] Dépendance front `@svg-maps/world` (carte, CC BY 4.0) et liste des pays en français via `Intl.DisplayNames` sans dépendance supplémentaire
- [fix] En environnement de test, ActiveJob utilise l'adaptateur `:test` au lieu de GoodJob : un `perform_later` dans un test exécutait sinon le job pour de vrai (appel OpenAI)

### 2026-07-06 — Séparation du CRM des contacts
- [feat] Nouvel onglet CRM (`/crm`) distinct de la page Contacts : liste des contacts suivis commercialement avec priorité, dernier contact + moyen, prochain rendez-vous et notes dédiées, plus une alerte « à relancer » pour les échéances dépassées
- [refactor] Extraction de l'ancien système « à rappeler » hors de ContactsPage.vue (le bouton devient « Ajouter au CRM » / « Retirer du CRM »), avec une barre d'onglets Contacts/CRM partagée entre les deux pages
- [db] Nouveau modèle `CrmProfile` (une entrée par contact suivi) ; migration des données existantes `callback_pending`/`callback_on` puis suppression de ces colonnes sur `contacts`
- [chore] Modèle CrmProfile exposé en lecture/écriture au subagent Alfred (skills life-dashboard et life-dashboard-write) et périmètre documenté dans CLAUDE.md

### 2026-06-18 — Raffinements module Entreprises & PDF
- [db] Ajout des colonnes `ape_code` et `idcc` sur les entreprises
- [feat] Champs Code APE/NAF et IDCC (convention collective) dans le formulaire entreprise et affichés sur la fiche détail
- [feat] Ajout de la forme juridique « Entreprise individuelle » (EI)
- [improve] La fiche détail entreprise affiche désormais toutes les informations (identification complète, finances, contact, notes), plus seulement un extrait
- [improve] Champ Description des lignes de devis/facture transformé en zone de texte multi-lignes pour rédiger de vraies descriptions
- [ui] PDF devis/facture : suppression du gros titre en haut, forme juridique déplacée sous le nom dans le bloc Émetteur

### 2026-06-11 — Refonte module Entreprises (devis/factures/clients)
- [refactor] Éclatement de la page Entreprises monolithique : index épuré (cards cliquables + aperçu budget) et nouvelle page détail `/companies/:id` en dashboard à onglets (Budget / Devis / Factures / Clients / Documents)
- [feat] Carnet de clients enregistrés par entreprise (modèle Client), réutilisable pour pré-remplir devis et factures
- [feat] Budget d'entreprise calculé depuis les factures (CA encaissé, en attente, devis acceptés non facturés) exposé via l'API
- [feat] Upload de documents libres (KBIS, statuts, attestations…) rattachés à l'entreprise, stockés sur OVH S3
- [improve] Documents devis/factures et autres docs désormais filtrés par entreprise (rattachement `company_id` sur Document)
- [refactor] Extraction des modales devis/facture/client en composants réutilisables et d'un composable de formatage partagé (useFormat)
- [db] Table `clients` + FK `client_id` (devis/factures) et `company_id` (documents), toutes nullables
- [chore] Modèle Client ajouté à la whitelist lecture du skill Alfred life-dashboard (exclu de l'écriture)

### 2026-06-11 — Modules CV & Documents
- [feat] Module CV : expériences, formations, compétences, centres d'intérêt et réglages
- [feat] Module Documents pour le stockage de fichiers
- [db] Mise en place d'Active Storage (tables + migrations)

### 2026-04-09 — Modules de base du dashboard
- [feat] Ajout des premières pages et modules (contacts, budget, santé, sites utiles…)

### 2026-01 → 2026-03 — Mise à niveau du socle
- [chore] Montée de version de Rails et des dépendances
- [fix] Corrections du boilerplate

### 2025-09 → 2025-10 — Mise en place du boilerplate SPA
- [infra] Initialisation du boilerplate Rails + Vue.js (SPA)
- [chore] Passage au gestionnaire de paquets npm
- [chore] Mise à jour de Vite, Vue et Tailwind
