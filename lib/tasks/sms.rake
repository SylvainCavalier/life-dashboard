namespace :sms do
  desc "Etat de la connexion Twilio et correspondants autorises"
  task check: :environment do
    puts "TWILIO_ACCOUNT_SID  : #{TwilioSms.account_sid ? 'present' : 'ABSENT'}"
    puts "TWILIO_AUTH_TOKEN   : #{TwilioSms.auth_token ? 'present' : 'ABSENT'}"
    puts "TWILIO_PHONE_NUMBER : #{TwilioSms.number || 'ABSENT'}"
    puts "Webhook a declarer  : https://#{ENV.fetch('APP_HOST', '<APP_HOST>')}/webhooks/twilio/sms (POST)"
    puts "Notifications push  : #{PushNotifications.configured? ? "#{PushSubscription.count} appareil(s)" : 'non configurees'}"
    puts "Correspondants      : #{SmsCorrespondent.count}"
    SmsCorrespondent.ordered.each do |correspondent|
      puts "  ##{correspondent.id} #{correspondent.name} #{correspondent.phone}#{' (Sylvain)' if correspondent.owner?}#{' [desactive]' unless correspondent.enabled?}"
    end
  end

  desc "Autorise un numero : PHONE=... NAME=... [OWNER=1]"
  task allow: :environment do
    correspondent = SmsCorrespondent.for_phone(ENV.fetch("PHONE")) || SmsCorrespondent.new(phone: ENV.fetch("PHONE"))
    correspondent.update!(name: ENV.fetch("NAME"), owner: ENV["OWNER"] == "1", enabled: true)
    puts "Autorise : ##{correspondent.id} #{correspondent.name} #{correspondent.phone}"
  end

  desc "Envoie un texto a un correspondant autorise : ID=... BODY=..."
  task send: :environment do
    message = SmsCorrespondent.find(ENV.fetch("ID")).send_text!(ENV.fetch("BODY"))
    puts "Envoye a Twilio : #{message.twilio_sid}"
  end
end
