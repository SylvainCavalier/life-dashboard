# Transcription Voxtral avec diarisation, commune aux Reunions et a l'outil Videos :
# `transcript` (jsonb) est une liste de segments { "speaker", "start", "end", "text" }
# et `speaker_names` (jsonb) associe un code d'intervenant a un nom.
module SpeakerTranscript
  extend ActiveSupport::Concern

  included do
    validate :speaker_names_is_a_hash
  end

  class_methods do
    def timecode(seconds)
      total = seconds.to_i
      Kernel.format("%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    end
  end

  # Intervenants dans leur ordre d'apparition.
  def speakers
    transcript.map { |segment| segment["speaker"] }.uniq
  end

  # "speaker_2" -> nom donne par Sylvain (ou devine a la synthese), sinon "Intervenant 2".
  # Apres une reprise d'enregistrement (Reunions), les voix de la partie 2 sont numerotees
  # a part ("p2_speaker_1") : rien ne garantit que Voxtral les rattache aux memes personnes.
  def speaker_label(speaker)
    return speaker_names[speaker] if speaker_names[speaker].present?

    part, number = speaker.to_s.match(/\Ap(\d+)_speaker_(\d+)\z/)&.captures
    return "Intervenant #{number} (partie #{part})" if part

    "Intervenant #{speaker.to_s[/\d+/] || speaker}"
  end

  # Segments consecutifs du meme intervenant fusionnes en tours de parole.
  def turns
    transcript.each_with_object([]) do |segment, acc|
      if acc.last && acc.last["speaker"] == segment["speaker"]
        acc.last["text"] = "#{acc.last['text']} #{segment['text']}"
        acc.last["end"] = segment["end"]
      else
        acc << segment.slice("speaker", "start", "end", "text")
      end
    end
  end

  # Transcription lisible, une ligne par tour : "[00:12:04] Marie : ...".
  def transcript_text
    turns.map { |turn| "[#{self.class.timecode(turn['start'])}] #{speaker_label(turn['speaker'])} : #{turn['text']}" }.join("\n")
  end

  # Tours de parole pour le modele de synthese : il doit pouvoir rattacher ses noms aux
  # codes, on garde donc le code a cote du nom deja connu.
  def transcript_for_model
    turns.map do |turn|
      named = speaker_names[turn["speaker"]].presence
      label = named ? "#{turn['speaker']} = #{named}" : turn["speaker"]
      "[#{self.class.timecode(turn['start'])}] [#{label}] #{turn['text']}"
    end.join("\n")
  end

  private

  def speaker_names_is_a_hash
    errors.add(:speaker_names, "doit associer un intervenant a un nom") unless speaker_names.is_a?(Hash)
  end
end
