module Alfred
  module Corpus
    # Parcourt tous les modeles du registre. Un enregistrement en echec n'arrete pas
    # le parcours : l'erreur est consignee sur son AlfredIndexEntry.
    class Reindexer
      Report = Struct.new(:indexed, :skipped, :removed, :failed, keyword_init: true)

      def initialize(models: Corpus.indexed_models, force: false, logger: nil)
        @models = models
        @force = force
        @logger = logger
      end

      def call
        report = Report.new(indexed: 0, skipped: 0, removed: 0, failed: 0)
        @models.each do |name|
          name.constantize.find_each do |record|
            result = Indexer.call(record, force: @force)
            if result.status == "removed" then report.removed += 1
            elsif result.skipped then report.skipped += 1
            else report.indexed += 1
            end
          rescue StandardError => e
            report.failed += 1
            @logger&.call("  ECHEC #{name}##{record.id} : #{e.message.truncate(200)}")
          end
          @logger&.call("#{name} : fait")
        end
        purge_orphans
        report
      end

      private

      # Passages dont la source a disparu sans callback (delete_all, SQL direct...).
      def purge_orphans
        AlfredChunk.distinct.pluck(:source_type).each do |type|
          klass = type.safe_constantize
          scope = AlfredChunk.where(source_type: type)
          scope = scope.where.not(source_id: klass.select(:id)) if klass && Corpus.indexed_models.include?(type)
          scope.delete_all
          entries = AlfredIndexEntry.where(source_type: type)
          entries = entries.where.not(source_id: klass.select(:id)) if klass && Corpus.indexed_models.include?(type)
          entries.delete_all
        end
      end
    end
  end
end
