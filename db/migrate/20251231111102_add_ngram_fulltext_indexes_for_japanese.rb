class AddNgramFulltextIndexesForJapanese < ActiveRecord::Migration[8.2]
  def up
    return if ActiveRecord::Base.connection.adapter_name == "SQLite"

    # MySQL ngram parser is required for proper Japanese/CJK tokenization
    # Drop existing full-text indexes and recreate with ngram parser
    # Note: This operation may take time on large tables as it rebuilds the full-text index
    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      say "Rebuilding full-text index for #{table_name}...", true

      # Remove existing full-text index
      remove_index table_name, name: index_name, type: :fulltext

      # Create new full-text index with ngram parser for Japanese support
      execute <<-SQL
        CREATE FULLTEXT INDEX #{index_name}
        ON #{table_name} (account_key, content, title)
        WITH PARSER ngram
      SQL
    end
  end

  def down
    return if ActiveRecord::Base.connection.adapter_name == "SQLite"

    # Restore original full-text indexes without ngram parser
    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      # Remove ngram full-text index
      execute "DROP INDEX #{index_name} ON #{table_name}"

      # Recreate standard full-text index
      add_index table_name, [:account_key, :content, :title], type: :fulltext, name: index_name
    end
  end
end

