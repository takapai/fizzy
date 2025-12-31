module Search::Stemmer
  extend self

  STEMMER = Mittens::Stemmer.new

  def stem(value)
    if value.present?
      value.split(/\s+/).filter_map do |word|
        if contains_cjk?(word)
          word
        else
          cleaned_word = word.gsub(/[^\w\s]/, "")
          if cleaned_word.present?
            STEMMER.stem(cleaned_word.downcase)
          else
            nil
          end
        end
      end.join(" ")
    else
      value
    end
  end

  private
    def contains_cjk?(text)
      text.match?(/\p{Han}|\p{Hiragana}|\p{Katakana}/)
    end
end
