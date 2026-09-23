module Alfred
  module Corpus
    # Indexe UN enregistrement : fiche (champs) et, s'il y en a un, texte du fichier
    # joint. Reprenable et econome : chaque moitie a son empreinte, on ne recalcule
    # que ce qui a change (l'OCR d'un scan n'est jamais repaye pour une simple
    # modification des notes du document).
    class Indexer
      Result = Struct.new(:status, :chunks_count, :skipped, keyword_init: true)

      def self.call(record, **opts) = new(record, **opts).call

      # Texte integral du fichier joint, recolle depuis les passages indexes (sans
      # l'en-tete ajoute a chacun). nil si le fichier n'est pas (encore) indexe.
      def self.file_text(record, chunker: Chunker.new)
        chunks = AlfredChunk.for_source(record).where(kind: "file").order(:position).pluck(:content)
        return nil if chunks.empty?

        chunker.join(chunks.map { |chunk| chunk.split("\n", 2).last.to_s })
      end

      def initialize(record, embedding_provider: Embeddings.default, extractor: TextExtractor.new,
                     chunker: Chunker.new, force: false)
        @record = record
        @config = Corpus.config_for(record)
        @embedding_provider = embedding_provider
        @extractor = extractor
        @chunker = chunker
        @force = force
      end

      def call
        raise ArgumentError, "#{@record.class} n'est pas dans Alfred::Corpus::REGISTRY" if @config.nil? || @config[:parent]

        return remove! if @config[:only_if] && !@config[:only_if].call(@record)

        entry = AlfredIndexEntry.find_or_initialize_by(source_type: @record.class.name, source_id: @record.id)
        renderer = RecordRenderer.new(@record, config: @config)

        record_changed = index_record(entry, renderer)
        file_changed = index_file(entry, renderer)

        entry.update!(status: "indexed", error: nil, indexed_at: Time.current,
                      chunks_count: AlfredChunk.for_source(@record).count)
        Result.new(status: "indexed", chunks_count: entry.chunks_count, skipped: !record_changed && !file_changed)
      rescue StandardError => e
        entry&.update(status: "failed", error: "#{e.class}: #{e.message}".truncate(1000))
        raise
      end

      private

      def remove!
        AlfredChunk.for_source(@record).delete_all
        AlfredIndexEntry.where(source_type: @record.class.name, source_id: @record.id).delete_all
        Result.new(status: "removed", chunks_count: 0, skipped: false)
      end

      def index_record(entry, renderer)
        text = renderer.text
        digest = Digest::SHA256.hexdigest(text)
        return false if !@force && entry.record_digest == digest && chunks?("record")

        replace_chunks("record", @chunker.call(text), renderer)
        entry.record_digest = digest
        true
      end

      def index_file(entry, renderer)
        attachment = @config[:file] && @record.public_send(@config[:file])
        unless attachment&.attached?
          AlfredChunk.for_source(@record).where(kind: "file").delete_all
          entry.assign_attributes(file_digest: nil, file_extractor: nil)
          return false
        end

        blob = attachment.blob
        if !@force && entry.file_digest == blob.checksum
          # Le texte du fichier n'a pas change, mais son libelle ou sa date peut-etre.
          AlfredChunk.for_source(@record).where(kind: "file").update_all(label: renderer.label, source_date: renderer.source_date)
          return false
        end

        text, extractor = @extractor.call(blob)
        # Chaque passage du fichier rappelle de quel document il vient : un extrait
        # de releve sans son titre est introuvable et inutilisable.
        # En-tete sur UNE ligne : `file_text` le retire en coupant au premier saut de ligne.
        header = "#{@config[:title]} : #{renderer.label.to_s.squish}" \
                 "#{" (#{renderer.source_date.strftime('%d/%m/%Y')})" if renderer.source_date}\n"
        replace_chunks("file", @chunker.call(text).map { |chunk| header + chunk }, renderer)
        entry.assign_attributes(file_digest: blob.checksum, file_extractor: extractor)
        true
      end

      def chunks?(kind)
        AlfredChunk.for_source(@record).where(kind: kind).exists?
      end

      def replace_chunks(kind, contents, renderer)
        embeddings = contents.empty? ? [] : @embedding_provider.embed(texts: contents)

        AlfredChunk.transaction do
          AlfredChunk.for_source(@record).where(kind: kind).delete_all
          contents.each_with_index do |content, position|
            AlfredChunk.create!(
              source: @record, kind: kind, position: position, label: renderer.label,
              source_date: renderer.source_date, content: content,
              token_count: (content.length / Chunker::CHARS_PER_TOKEN.to_f).ceil,
              embedding: embeddings[position]
            )
          end
        end
      end
    end
  end
end
