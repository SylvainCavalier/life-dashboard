# Historique – Life Dashboard

Journal de bord des sessions de travail, par ordre antéchronologique (le plus récent en haut).
Les nouvelles entrées sont ajoutées par la commande `/historyupdate` en fin de session.

---

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
