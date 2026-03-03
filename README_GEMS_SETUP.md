# Gems Setup Instructions

This boilerplate includes several pre-configured gems. Some require additional setup steps after creating your database.

## Ready-to-Use Gems ✅

These gems are already configured and functional:

- **good_job** - Background jobs with PostgreSQL
- **lograge** - Structured logging in production  
- **rack-attack** - Rate limiting and attack protection
- **secure_headers** - Security headers (CSP, HSTS, etc.)
- **pagy** - Lightweight and performant pagination
- **pundit** - Authorization (included in ApplicationController)
- **invisible_captcha** - Anti-spam protection without visible captcha
- **letter_opener** - Email preview in development

## Gems Requiring Post-Database Configuration 🔧

### 1. Devise (Authentication)

⚠️ **Important**: This boilerplate is pre-configured for Devise. See the detailed guide:

📖 **[Complete Devise Installation Guide](README_DEVISE_INTEGRATION.md)**

Quick summary:
```bash
rails generate devise:install
rails generate devise User
rails db:migrate
```

Then uncomment the `before_action` lines in `ApplicationController`.

### 2. AnnotateRb (Automatic model documentation)

After creating your first models:

```bash
# Generate configuration
rails generate annotate_rb:install

# Annotate all existing models
bundle exec annotaterb models
```

### 3. Good Job (Job tables)

```bash
# Create tables for good_job
rails generate good_job:install
rails db:migrate

# Then uncomment in config/initializers/good_job.rb:
# config.active_job.queue_adapter = :good_job
```

### 4. Paper Trail (Model versioning)

```bash
# Generate version tables
rails generate paper_trail:install
rails db:migrate

# Then add to your models:
# has_paper_trail
```

### 5. PG Search (Full-text search)

```bash
# Add to your models:
# include PgSearch::Model
# pg_search_scope :search_by_title, against: :title
```

### 6. Friendly ID (Friendly URLs)

```bash
# Generate configuration
rails generate friendly_id

# Add to your models:
# extend FriendlyId
# friendly_id :title, use: :slugged
```

## Recommended Additional Configuration

### Environment Variables

Create a `.env` file if needed:

```env
# PostgreSQL (standard variables)
PGUSER=postgres
PGPASSWORD=your_password
PGHOST=localhost

# Production
DATABASE_URL=postgres://user:pass@host:5432/dbname

# Rails
RAILS_MASTER_KEY=your_master_key_here
```

### Good Job Routes (optional)

Add to `config/routes.rb` to access the dashboard:

```ruby
# Development only
mount GoodJob::Engine => "/good_job" if Rails.env.development?
```

## 🚀 Quick Start (without database)

To test the boilerplate immediately, see instructions in [README.md](README.md) "Quick Demo" section.

## Recommended Installation Order (with database)

1. **Remove boilerplate mode:**
   ```bash
   rm config/initializers/disable_db_checks.rb
   ```

2. Create database: `rails db:create`
3. Install Devise if needed
4. Install Good Job: `rails generate good_job:install && rails db:migrate`  
5. Install Paper Trail if needed
6. Generate your models
7. Install AnnotateRb: `rails generate annotate_rb:install && bundle exec annotaterb models`
8. Configure Friendly ID on your models if needed

## Important Notes

- **Meta Tags**: Add `<%= display_meta_tags %>` to your layout
- **Image Processing**: Configured for Active Storage
- **Pundit**: Create your policies in `app/policies/`
- **Pagy**: Use `pagy()` in your controllers and `pagy_nav()` in your views
