module Alfred
  module Sms
    # Creneaux occupes et libres de Sylvain, calcules en Ruby depuis l'agenda. Ne sort JAMAIS
    # le titre, le lieu ou la description d'un evenement : cette classe est la frontiere qui
    # protege le contenu de l'agenda, quoi que le texto demande au modele.
    class Availability
      DAY_START_HOUR = 8
      DAY_END_HOUR = 21
      MAX_DAYS = 31
      MAX_AHEAD = 180.days
      WEEKDAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
      # Une echeance (URSSAF, loyer...) occupe l'agenda sans occuper Sylvain.
      IGNORED_TYPES = %w[echeance].freeze

      def initialize(from_date, to_date)
        @from = parse(from_date)
        @to = parse(to_date)
        raise ArgumentError, "La fin de la periode precede son debut" if @to < @from
        raise ArgumentError, "#{MAX_DAYS} jours au plus par demande" if (@to - @from).to_i >= MAX_DAYS
        raise ArgumentError, "Periode passee : seules les disponibilites a venir sont donnees" if @to < Date.current
        raise ArgumentError, "Periode trop lointaine (6 mois au plus)" if @from > MAX_AHEAD.from_now.to_date

        @from = [@from, Date.current].max
      end

      def call
        events = load_events
        { timezone: "Europe/Paris", days: (@from..@to).map { |date| day(date, events) } }
      end

      private

      def parse(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        raise ArgumentError, "Date invalide : #{value.to_s.truncate(30)} (format AAAA-MM-JJ)"
      end

      # [[debut, fin, journee entiere ?]]. Conventions d'Event : journee entiere = end_time
      # sur le dernier jour inclus ; sans end_time, un rendez-vous dure une heure.
      def load_events
        range_start = @from.in_time_zone.beginning_of_day
        range_end = @to.in_time_zone.end_of_day
        Event.where(start_time: ..range_end).where(start_time: (range_start - MAX_DAYS.days)..)
             .where.not(event_type: IGNORED_TYPES)
             .pluck(:start_time, :end_time, :all_day)
             .map { |start, finish, all_day| interval(start, finish, all_day) }
             .select { |_, finish, _| finish >= range_start }
      end

      def interval(start, finish, all_day)
        return [start, (finish || start).end_of_day, true] if all_day

        [start, finish || (start + 1.hour), false]
      end

      def day(date, events)
        opening = date.in_time_zone.change(hour: DAY_START_HOUR)
        closing = date.in_time_zone.change(hour: DAY_END_HOUR)
        opening = [opening, Time.current].max if date == Date.current

        of_day = events.select { |start, finish, _| start <= date.in_time_zone.end_of_day && finish >= date.in_time_zone.beginning_of_day }
        timed = of_day.reject(&:last).sort_by(&:first)
        {
          date: date.iso8601, weekday: WEEKDAYS[date.wday],
          all_day_event: of_day.any?(&:last),
          busy: timed.map { |start, finish, _| slot(start, finish, date) },
          free: free_slots(timed, opening, closing)
        }
      end

      def free_slots(timed, opening, closing)
        cursor = opening
        slots = []
        timed.each do |start, finish, _|
          slots << { start: cursor.strftime("%H:%M"), end: [start, closing].min.strftime("%H:%M") } if start > cursor && cursor < closing
          cursor = [cursor, finish].max
        end
        slots << { start: cursor.strftime("%H:%M"), end: closing.strftime("%H:%M") } if cursor < closing
        slots
      end

      # Un rendez-vous a cheval sur plusieurs jours est coupe a minuit.
      def slot(start, finish, date)
        from = start.to_date < date ? "00:00" : start.in_time_zone.strftime("%H:%M")
        to = finish.to_date > date ? "23:59" : finish.in_time_zone.strftime("%H:%M")
        { start: from, end: to }
      end
    end
  end
end
