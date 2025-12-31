class Search::Highlighter
  OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  CLOSING_MARK = "</mark>"
  ELIPSIS = "..."

  attr_reader :query

  def initialize(query)
    @query = query
  end

  def highlight(text)
    result = text.dup

    terms.each do |term|
      if contains_cjk?(term)
        # For Japanese/CJK terms, match directly without word boundaries
        result.gsub!(/(#{Regexp.escape(term)})/i) do |match|
          "#{OPENING_MARK}#{match}#{CLOSING_MARK}"
        end
      else
        # For English terms, use word boundaries
        result.gsub!(/\b(#{Regexp.escape(term)}\w*)\b/i) do |match|
          "#{OPENING_MARK}#{match}#{CLOSING_MARK}"
        end
      end
    end

    escape_highlight_marks(result)
  end

  def snippet(text, max_words: 20)
    if contains_cjk?(text)
      # For Japanese/CJK text, find match position and extract characters around it
      match_pos = nil
      matched_term = nil
      terms.each do |term|
        pos = text.index(term)
        if pos
          match_pos = pos
          matched_term = term
          break
        end
      end

      if match_pos
        # Extract characters around the match (approximately max_words * 2 for CJK)
        char_limit = max_words * 2
        start_pos = [ 0, match_pos - char_limit / 2 ].max
        end_pos = [ text.length, match_pos + matched_term.length + char_limit / 2 ].min

        snippet_text = text[start_pos...end_pos]
        snippet_text = "...#{snippet_text}" if start_pos > 0
        snippet_text = "#{snippet_text}..." if end_pos < text.length

        highlight(snippet_text)
      else
        # No match found, truncate
        text.truncate(max_words * 2, omission: "...")
      end
    else
      # For English text, use word-based splitting
      words = text.split(/\s+/)
      match_index = words.index do |word|
        terms.any? { |term| word.downcase.include?(term.downcase) }
      end

      if words.length <= max_words
        highlight(text)
      elsif match_index
        start_index = [ 0, match_index - max_words / 2 ].max
        end_index = [ words.length - 1, start_index + max_words - 1 ].min

        snippet_text = words[start_index..end_index].join(" ")
        snippet_text = "...#{snippet_text}" if start_index > 0
        snippet_text = "#{snippet_text}..." if end_index < words.length - 1

        highlight(snippet_text)
      else
        text.truncate_words(max_words, omission: "...")
      end
    end
  end

  private
    def terms
      @terms ||= begin
        terms = []

        query.scan(/"([^"]+)"/) do |phrase|
          terms << phrase.first
        end

        unquoted = query.gsub(/"[^"]+"/, "")
        unquoted.split(/\s+/).each do |word|
          terms << word if word.present?
        end

        terms.uniq
      end
    end

    def contains_cjk?(text)
      text.match?(/\p{Han}|\p{Hiragana}|\p{Katakana}/)
    end

    def escape_highlight_marks(html)
      CGI.escapeHTML(html)
        .gsub(CGI.escapeHTML(OPENING_MARK), OPENING_MARK.html_safe)
        .gsub(CGI.escapeHTML(CLOSING_MARK), CLOSING_MARK.html_safe)
        .html_safe
    end
end
