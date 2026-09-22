# Alfred : synchronisation du corpus. Chaque modele du registre (Alfred::Corpus::REGISTRY)
# recoit des callbacks after_commit qui enfilent sa reindexation.
Rails.application.config.to_prepare do
  Alfred::Corpus.install_hooks!
end
