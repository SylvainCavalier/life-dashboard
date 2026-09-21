# Mise en ligne — Heroku

Procedure de deploiement du Life Dashboard. Application **mono-utilisateur** :
un seul compte, aucune inscription publique, aucun contenu destine a etre indexe.

---

## 1. Prerequis

- CLI Heroku installee et connectee (`heroku login`)
- `config/master.key` disponible en local (non versionne) — **sans lui, les
  champs chiffres par Active Record Encryption (`PasswordEntry#password`) sont
  irrecuperables en production**
- Le fichier `.env` local, pour recopier les cles OVH

## 2. Creation de l'application

```bash
heroku create life-dashboard-prive --region eu
heroku addons:create heroku-postgresql:essential-0 --app life-dashboard-prive
```

La region `eu` (Dublin) evite de faire transiter des donnees personnelles
(profil sante, numero de securite sociale, IBAN) par des serveurs americains.

Buildpacks, dans cet ordre — Node d'abord, il doit installer les dependances
avant que `assets:precompile` ne declenche le build Vite :

```bash
heroku buildpacks:add heroku/nodejs --app life-dashboard-prive
heroku buildpacks:add heroku/ruby   --app life-dashboard-prive

# Chrome headless, pour l'export PDF du CV (Grover/Puppeteer).
# Sans lui, l'export bascule automatiquement sur l'impression navigateur.
heroku buildpacks:add --index 1 heroku-community/google-chrome --app life-dashboard-prive
```

## 3. Variables d'environnement

```bash
heroku config:set --app life-dashboard-prive \
  RAILS_ENV=production \
  RAILS_MASTER_KEY="$(cat config/master.key)" \
  RAILS_LOG_LEVEL=info \
  APP_HOST=dashboard.mondomaine.fr \
  CALENDAR_FEED_TOKEN="$(openssl rand -hex 32)" \
  OVH_S3_ACCESS_KEY=... \
  OVH_S3_SECRET_KEY=... \
  OVH_S3_BUCKET=... \
  OVH_S3_REGION=gra \
  OVH_S3_ENDPOINT=https://s3.gra.io.cloud.ovh.net \
  LANGOCHAT_API_URL=... \
  LANGOCHAT_API_KEY=... \
  MISTRAL_API_KEY=... \
  OPENAI_API_KEY=... \
  OPENAI_TRIP_MODEL=gpt-5.6-sol
```

`OPENAI_API_KEY` sert au module Voyages (rapport IA via l'API Responses et la
recherche web). `OPENAI_TRIP_MODEL` est optionnel (defaut `gpt-5.6-sol`).

Le module Sentinelle (veille hebdomadaire) utilise aussi `OPENAI_API_KEY`, et en option
`OPENAI_SENTINEL_MODEL` / `OPENAI_SENTINEL_SUMMARY_MODEL`. Il lui faut en plus :

```bash
heroku config:set \
  PISTE_CLIENT_ID=... \
  PISTE_CLIENT_SECRET=... \
  TAVILY_API_KEY=...
```

`PISTE_*` : identifiants OAuth de piste.gouv.fr (application abonnee aux API Judilibre et
Legifrance), sans lesquels l'onglet Droit du travail ne collecte que la doctrine.
`TAVILY_API_KEY` est facultative (recherche web de l'onglet Desinformation, en complement des flux RSS).
`bin/rails sentinel:check` affiche ce qui manque. Une veille tourne dans le dyno web (GoodJob async) et
dure quelques minutes : un redemarrage du dyno l'interrompt, la relancer reprend ou elle s'est arretee.

| Variable | Role |
|---|---|
| `RAILS_MASTER_KEY` | Dechiffre `credentials.yml.enc` (secret_key_base **et** cles Active Record Encryption) |
| `APP_HOST` | Domaine autorise. **Tant qu'il n'est pas pose, l'app repond aussi sur `*.herokuapp.com`** (voir §6) |
| `CALENDAR_FEED_TOKEN` | Secret du flux ICS `/api/calendar.ics?token=...` |
| `GOOD_JOB_EXECUTION_MODE` | Optionnel. `async` par defaut (jobs dans le process web) ; `external` si un dyno worker est ajoute |

## 4. Domaine et dyno

```bash
heroku domains:add dashboard.mondomaine.fr --app life-dashboard-prive
heroku certs:auto:enable --app life-dashboard-prive
heroku ps:type web=basic --app life-dashboard-prive
```

Puis creer chez le registrar l'enregistrement CNAME indique par
`heroku domains --app life-dashboard-prive`.

**Ne pas** deposer le domaine dans la Search Console, ni le lier depuis un site
public, ni le poster nulle part : la premiere source d'indexation d'un domaine
prive, ce sont les backlinks, pas les crawlers.

### Export PDF du CV

`config/initializers/grover.rb` lance Chrome avec `--no-sandbox`,
`--disable-dev-shm-usage` et `--single-process` (obligatoires dans un
conteneur), et lit le chemin du binaire dans `GOOGLE_CHROME_BIN`, pose par le
buildpack.

Si Chrome manque ou se fait tuer par la limite memoire du dyno (512 Mo sur un
Basic, et Chrome en consomme facilement 200), l'API repond `503` avec
`{"fallback": "browser_print"}` et l'interface bascule d'elle-meme sur la boite
d'impression du navigateur, avec exactement le meme document et la meme feuille
de style. **L'export reste donc fonctionnel dans tous les cas** ; c'est juste
« Enregistrer au format PDF » a la place d'un telechargement direct.

Si l'export serveur s'avere trop juste en memoire, l'option la plus simple est
de retirer le buildpack Chrome : le repli navigateur devient le comportement
permanent, sans rien casser.

### Module Downloader

Le module a besoin des binaires `yt-dlp` et `ffmpeg`, absents d'Heroku par
defaut. Sans eux rien ne casse : la page affiche un bandeau « Module
indisponible sur ce serveur » (`GET /api/video_downloads/availability`) et les
telechargements lances passent en echec. Pour l'activer, ajouter un buildpack
ffmpeg et un buildpack (ou un `bin/` embarque) fournissant `yt-dlp`, puis
verifier avec `heroku run rails downloader:check`.

Limites a connaitre avant de s'y fier en production :

- **YouTube bloque souvent les IP de datacenter** (« Sign in to confirm you're
  not a bot »). En local, `YT_DLP_COOKIES_FROM_BROWSER=chrome` contourne le
  probleme en empruntant les cookies du navigateur ; sur un dyno il n'y a pas de
  navigateur, la variable reste vide.
- **Le stockage « local » n'a de sens qu'en local** : le disque d'un dyno est
  ephemere, le fichier disparait au redemarrage (l'interface l'indique alors
  comme supprime). En production, utiliser le stockage cloud.
- GoodJob tourne dans le process web (dyno Basic, 512 Mo) : un long
  telechargement plus le remux ffmpeg occupent ce process pendant ce temps.

L'usage nominal reste donc la machine locale, comme pour l'ancien projet
`video-downloader`.

## 5. Premier deploiement

```bash
git push heroku master
```

Le `release:` du Procfile joue les migrations automatiquement. Ensuite, creer le
compte unique (mot de passe de 14 caracteres minimum) :

```bash
heroku run rails owner:bootstrap --app life-dashboard-prive
```

Cette tache cree le compte `sylv.cavalier@gmail.com` avec un mot de passe
provisoire connu, **volontairement faible**, et pose le drapeau
`must_change_password`.

> **Connecte-toi immediatement apres cette commande.** Tant que le mot de passe
> provisoire n'est pas remplace, il est valide sur un site expose a Internet.
> C'est la seule fenetre de risque de toute la procedure, et elle doit durer
> quelques minutes, pas quelques jours.

A la premiere connexion, l'application bloque sur `/account/password` : toutes
les pages y redirigent et l'API repond `403`. Le mot de passe provisoire ne peut
donc servir qu'une fois. Le nouveau mot de passe doit faire 14 caracteres
minimum.

Ensuite, il se change a tout moment depuis le bouton **Mot de passe** dans
l'en-tete du dashboard. En cas de besoin :

```bash
heroku run rails owner:reset_password --app life-dashboard-prive       # saisie interactive
heroku run rails owner:force_password_change --app life-dashboard-prive # rebloque a la prochaine connexion
heroku run rails owner:unlock --app life-dashboard-prive                # apres 5 echecs de connexion
```

## 6. Migration des donnees locales

La base fait une dizaine de Mo et les fichiers sont **deja** sur OVH S3 (le
developpement utilise le meme bucket que la production, cf. `config/storage.yml`) :
il n'y a que la base a transferer.

```bash
# Sauvegarde locale, en excluant les tables de jobs (crons et jobs perimes)
pg_dump --no-owner --no-acl --format=custom \
  --exclude-table='good_job*' \
  life_dashboard_development > /tmp/life_dashboard.dump

# Restauration sur Heroku
heroku pg:backups:restore --app life-dashboard-prive  # si le dump est accessible en HTTP
# ou, plus simple pour une base de cette taille :
pg_restore --no-owner --no-acl --clean --if-exists \
  --dbname "$(heroku config:get DATABASE_URL --app life-dashboard-prive)" \
  /tmp/life_dashboard.dump
```

Puis rejouer les migrations (le dump ne contient pas la table `users`, creee
apres coup) et recreer le compte :

```bash
heroku run rails db:migrate --app life-dashboard-prive
heroku run rails owner:bootstrap --app life-dashboard-prive
```

Verification que le chiffrement a bien suivi :

```bash
heroku run rails runner 'puts PasswordEntry.first&.password.present?' --app life-dashboard-prive
```

Si cette commande leve une erreur de dechiffrement, c'est que `RAILS_MASTER_KEY`
ne correspond pas au `config/master.key` local.

## 7. Verifications apres mise en ligne

```bash
D=https://dashboard.mondomaine.fr

curl -sI  $D/                      | grep -i "location\|x-robots-tag"   # 302 vers /users/sign_in
curl -s   $D/api/personal_profile -H 'Accept: application/json' -o /dev/null -w '%{http_code}\n'  # 401
curl -s   $D/api/password_entries -H 'Accept: application/json' -o /dev/null -w '%{http_code}\n'  # 401
curl -s   $D/robots.txt            | head -6                            # Disallow: /
curl -sI  https://life-dashboard-prive.herokuapp.com/ -o /dev/null -w '%{http_code}\n'  # 403 (APP_HOST)
```

## 8. Points connus a traiter apres la premiere mise en ligne

- **`MailAccount#password` n'est pas chiffre** en base, contrairement a
  `PasswordEntry#password`. A corriger (`encrypts :password` + re-chiffrement
  des lignes existantes).
- **Pas de 2FA.** Le compte unique donne acces au coffre-fort, a l'IBAN et au
  profil sante derriere un simple mot de passe. Le verrouillage apres 5 echecs
  (Devise :lockable) limite le bruteforce, mais ne remplace pas un second
  facteur.
- **Verifier l'export PDF du CV** apres la premiere mise en ligne : s'il tombe
  en repli navigateur, c'est que Chrome manque ou sature la memoire du dyno.
- **Sauvegardes.** `heroku pg:backups:schedule DATABASE_URL --at '03:00 Europe/Paris'`.
