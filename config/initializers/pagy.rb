# Pagy v43+ configuration
# https://ddnexus.github.io/pagy/

# Pagy v43 dramatically simplifies configuration
# Most settings are now automatic

# Basic options (optional - sensible defaults are provided)
Pagy.options[:limit] = 25        # items per page (was :items in v9)
Pagy.options[:size] = 5          # number of page links (simplified in v43)

# Usage in controllers:
#   @pagy, @records = pagy(:offset, Model.all)
#   @pagy, @records = pagy(:keyset, Model.order(:id).all)  # faster for large datasets
#
# Usage in views:
#   @pagy.series_nav              # default styling
#   @pagy.series_nav(:bootstrap)  # Bootstrap styling
#   @pagy.series_nav_js(:bootstrap)  # client-side responsive
#   @pagy.input_nav_js            # compact input style
