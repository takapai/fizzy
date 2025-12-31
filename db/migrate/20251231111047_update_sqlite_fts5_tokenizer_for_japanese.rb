class UpdateSQLiteFts5TokenizerForJapanese < ActiveRecord::Migration[8.2]

  def up
    return unless connection.adapter_name == "SQLite"

    # FTS5 virtual tables can't be altered, so we need to drop and recreate
    # Drop the old FTS5 table
    execute "DROP TABLE IF EXISTS search_records_fts"

    # Recreate FTS5 table with unicode61 tokenizer for Japanese support
    execute <<-SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='unicode61'
      )
    SQL

    # Re-index all existing data in batches for performance
    reindex_fts5_table
  end

  def down
    return unless connection.adapter_name == "SQLite"

    # Drop unicode61 FTS5 table
    execute "DROP TABLE IF EXISTS search_records_fts"

    # Recreate with porter tokenizer (original)
    execute <<-SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='porter'
      )
    SQL

    # Re-index all existing data in batches for performance
    reindex_fts5_table
  end

  private
    BATCH_SIZE = 1000

    def reindex_fts5_table
      # Process records in batches to avoid loading everything into memory
      total_count = connection.select_value("SELECT COUNT(*) FROM search_records").to_i
      processed = 0

      # Use a cursor-like approach with LIMIT/OFFSET for efficient batching
      offset = 0
      while offset < total_count
        transaction do
          # Fetch a batch of records
          batch = connection.select_rows(
            "SELECT id, title, content FROM search_records ORDER BY id LIMIT ? OFFSET ?",
            "Fetch Batch",
            [ BATCH_SIZE, offset ]
          )

          # Insert batch into FTS5 table within transaction for performance
          batch.each do |row|
            id, title, content = row
            connection.exec_query(
              "INSERT INTO search_records_fts(rowid, title, content) VALUES (?, ?, ?)",
              "Re-index Search Records",
              [ id, title || "", content || "" ]
            )
          end
        end

        offset += BATCH_SIZE
        processed = [ offset, total_count ].min
        say "Re-indexed #{processed} / #{total_count} records", true if processed % (BATCH_SIZE * 10) == 0
      end
    end
end

