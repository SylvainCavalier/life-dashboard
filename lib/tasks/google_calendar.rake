# Points d'entree scriptables de la synchronisation Google Calendar (Alfred).
namespace :google_calendar do
  desc "Configuration et connexion a l'agenda : rake google_calendar:check"
  task check: :environment do
    credentials = "ABSENTE"
    credentials = "ok (compte de service #{GoogleCalendar.service_account_email})" if GoogleCalendar.credentials_json
    puts "GOOGLE_CALENDAR_ID          #{GoogleCalendar.calendar_id || 'ABSENT'}"
    puts "GOOGLE_CALENDAR_CREDENTIALS #{credentials}"
    abort "Synchronisation desactivee : variables manquantes" unless GoogleCalendar.enabled?

    begin
      puts "Agenda                      #{GoogleCalendar::Client.new.calendar_name}"
    rescue GoogleCalendar::Client::Error => e
      abort "Connexion impossible : #{e.message}"
    end

    state = CalendarSync.current
    puts "Derniere synchronisation    #{state.last_synced_at&.strftime('%d/%m/%Y %H:%M') || 'jamais'} (#{state.status})"
    puts "  ! #{state.last_error}" if state.last_error.present?
    puts "Evenements lies a Google    #{Event.where.not(google_event_id: nil).count} sur #{Event.count}"
  end

  desc "Enfile une synchronisation (GoodJob) : rake google_calendar:sync"
  task sync: :environment do
    abort "Synchronisation desactivee : variables manquantes" unless GoogleCalendar.enabled?

    state = CalendarSync.run!
    puts "Synchronisation #{state.status}"
  end

  desc "Synchronise immediatement, sans GoodJob (debogage, Alfred) : rake google_calendar:sync_now"
  task sync_now: :environment do
    abort "Synchronisation desactivee : variables manquantes" unless GoogleCalendar.enabled?

    GoogleCalendarPullJob.perform_now
    state = CalendarSync.current
    if state.status == "done"
      puts "Termine : #{state.pulled_count} recu(s), #{state.pushed_count} pousse(s), " \
           "#{state.deleted_count} supprime(s)"
      puts "  ! #{state.last_error}" if state.last_error.present?
    else
      abort "Echec : #{state.last_error}"
    end
  end
end
