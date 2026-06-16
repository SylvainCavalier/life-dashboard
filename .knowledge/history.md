# Historique – Life Dashboard

Journal de bord des sessions de travail, par ordre antéchronologique (le plus récent en haut).
Les nouvelles entrées sont ajoutées par la commande `/historyupdate` en fin de session.

---

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
