module RedmineReleaseWikiSync
  module WikiContentPatch
    def self.prepended(base)
      base.after_commit :release_wiki_sync_after_commit
    end

    private

    def release_wiki_sync_after_commit
      RedmineReleaseWikiSync::Updater.call(self)
    rescue => e
      Rails.logger.error("[release_wiki_sync] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(20).join("\n")) if e.backtrace
    end
  end
end
