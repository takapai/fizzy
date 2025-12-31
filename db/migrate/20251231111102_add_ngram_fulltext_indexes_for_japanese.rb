class AddNgramFulltextIndexesForJapanese < ActiveRecord::Migration[8.2]
  def up
    return if ActiveRecord::Base.connection.adapter_name == "SQLite"

    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      say "Rebuilding full-text index for #{table_name}...", true

      remove_index table_name, name: index_name, type: :fulltext

      execute <<-SQL
        CREATE FULLTEXT INDEX #{index_name}
        ON #{table_name} (account_key, content, title)
        WITH PARSER ngram
      SQL
    end
  end

  def down
    return if ActiveRecord::Base.connection.adapter_name == "SQLite"

    16.times do |shard_id|
      table_name = "search_records_#{shard_id}"
      index_name = "index_search_records_#{shard_id}_on_account_key_and_content_and_title"

      execute "DROP INDEX #{index_name} ON #{table_name}"

      add_index table_name, [:account_key, :content, :title], type: :fulltext, name: index_name
    end
  end
end

