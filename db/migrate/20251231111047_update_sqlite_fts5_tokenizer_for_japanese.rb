class UpdateSQLiteFts5TokenizerForJapanese < ActiveRecord::Migration[8.2]

  def up
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS search_records_fts"

    execute <<-SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='unicode61'
      )
    SQL

    reindex_fts5_table
  end

  def down
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS search_records_fts"

    execute <<-SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='porter'
      )
    SQL

    reindex_fts5_table
  end

  private
    BATCH_SIZE = 1000

    def reindex_fts5_table
      total_count = connection.select_value("SELECT COUNT(*) FROM search_records").to_i
      processed = 0

      offset = 0
      while offset < total_count
        transaction do
          batch = connection.select_rows(
            "SELECT id, title, content FROM search_records ORDER BY id LIMIT ? OFFSET ?",
            "Fetch Batch",
            [ BATCH_SIZE, offset ]
          )

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

