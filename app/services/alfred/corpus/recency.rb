module Alfred
  module Corpus
    # Leger bonus de fraicheur, borne dans [FLOOR, 1.0] : sert a departager, jamais
    # a exclure. Le plancher de pertinence reste applique au cosine brut. Un plancher
    # bas enterrerait un vieux document pourtant le plus pertinent (un bail de 2015
    # reste LE bail) : ne pas descendre sous 0.8.
    module Recency
      HALF_LIFE_DAYS = ENV.fetch("ALFRED_RECENCY_HALF_LIFE_DAYS", "1080").to_f
      FLOOR = ENV.fetch("ALFRED_RECENCY_FLOOR", "0.9").to_f

      module_function

      def factor(date, as_of: Date.current)
        return 1.0 if date.nil?

        age_days = (as_of - date.to_date).to_f
        return 1.0 if age_days <= 0

        half_life = HALF_LIFE_DAYS.positive? ? HALF_LIFE_DAYS : 1.0
        FLOOR + (1.0 - FLOOR) * (0.5**(age_days / half_life))
      end
    end
  end
end
