QUERY = <<SQL
 prefix skosxl: <http://www.w3.org/2008/05/skos-xl#>
 prefix tportal: <http://translation.escoportal.eu/suggestions#>
 prefix dcterms: <http://purl.org/dc/terms/>

 select DISTINCT ?literal_form ?source where {
    ?s skosxl:literalForm "TERM_TO_TRANSLATE_PLACEHOLDER"@SOURCE_LANGUAGE_PLACEHOLDER .
    ?group tportal:suggestion ?s .
    ?group tportal:suggestion ?t .
    ?group dcterms:source ?source .
    ?t skosxl:literalForm ?literal_form .
    FILTER ( lang(?literal_form) IN (TARGET_LANGUAGES_PLACEHOLDER) )
 }
SQL

get '/' do
  content_type 'application/vnd.api+json'

  term, source_language, target_languages = params[:term], params[:source_language], params[:target_languages]

  log.info "Translation request received: [term='#{term}' - source_language='#{source_language}' - target_languages='#{target_languages}']"

  errors = validate_request(term, source_language, target_languages)
  return error(errors.join(', '), 422) unless errors.empty?

  results = query_term(term.strip, source_language.strip, target_languages.strip)

  {data: results}.to_json
end

helpers do

  def blank?(str)
    str.nil? || str.gsub(/\s/, '').empty?
  end

  def validate_request(term, source_language, target_languages)
    errors = []
    errors << 'term request parameter missing' if blank?(term)
    errors << 'source_language request parameter missing' if blank?(source_language)
    errors << 'target_languages request parameter missing' if blank?(target_languages)
    errors
  end

  def run_query(term, source_language, target_languages_as_string_for_query)
    query(QUERY
              .gsub('TERM_TO_TRANSLATE_PLACEHOLDER', term)
              .gsub('SOURCE_LANGUAGE_PLACEHOLDER', source_language.downcase)
              .gsub('TARGET_LANGUAGES_PLACEHOLDER', target_languages_as_string_for_query))
  end

  def query_term(original_term, source_language, target_languages)
    target_languages_as_string_for_query = target_languages.split(',').map { |lang| "\"#{lang.strip.downcase}\"" }.join(',')

    results_map = {}

    query_results = run_query(original_term, source_language, target_languages_as_string_for_query)

    if !query_results.empty?
      process_results(results_map, query_results, original_term)
      structure_results_as_json(results_map, original_term, true)
    else
      # Nothing found, let's try the individual parts then
      # Start by replacing punctuation characters with a space (why a space and not a blank: e.g. 'term1,term2' would otherwise become term1term2)
      term_without_punctuation = original_term.gsub /[[:punct:]]/, ' '

      term_parts = term_without_punctuation.split(' ')
      if term_parts.size > 1
        term_parts.each do |term_part|
          term_part = term_part.strip
          results_for_term = run_query(term_part, source_language, target_languages_as_string_for_query)
          process_results(results_map, results_for_term, term_part)
        end
      end
      structure_results_as_json(results_map, original_term, false)
    end

  end

  def structure_results_as_json(results_map, original_term, original_term_translated)
    results_map.map do |source, term_translations_map|
      translations = term_translations_map.map do |term, translations|
        translations_for_term = translations.map { |translation| {target_language: translation.language, translation: translation.literal_form} }
        {term: term, translations_for_term: translations_for_term}
      end
      {attributes: {source: source, original_term: original_term, original_term_translated: original_term_translated, translations: translations}}
    end
  end

  def process_results(results_map, results, term)
    results.each do |result|
      query_result = QueryResult.new(result)
      results_map[query_result.source] = {} unless results_map.has_key?(query_result.source)
      results_map[query_result.source][term] = [] unless results_map[query_result.source][term]
      results_map[query_result.source][term] << query_result
    end
  end

  class QueryResult
    attr_reader :source, :literal_form, :language

    def initialize(result)
      @source, @literal_form, @language = result[:source].to_s, result[:literal_form], result[:literal_form].language
    end
  end

end

