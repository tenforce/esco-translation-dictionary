# Mu Dictionary micro service
Microservice that returns translations from a dictionary.

## Requesting a translation
3 request parameters are required:

* term: The term that needs to be translated.
* source_language: The language of the term to be translated.
* target_languages: The languages to which the term needs to be translated. A comma-separated list of ISO-639 language codes.

When no match is found for the term and the term consists of multiple words, the term is split into its constituent parts and translations for each word are searched for.

The results are grouped per source.

The *original_term_translated* field indicates whether the term could be translated in its entirety.

If the original term could not be translated in its entirety, translations per term part will be returned (if any were found).
For each term, a group of translations will be returned.

## Example curl request

```
curl -X GET "http://192.168.99.100:32888/translate?term=party%20penalty&source_language=en&target_languages=fr,nl"
```

## Example answer to a curl request (the one above)

```
{
  "data": [
    {
      "attributes": {
        "source": "IATI",
        "original_term": "party penalty",
        "original_term_translated": false,
        "translations": [
          {
            "term": "party",
            "translations_for_term": [
              {
                "target_language": "fr",
                "translation": "partie"
              },
              {
                "target_language": "fr",
                "translation": "État partie"
              }
            ]
          },
          {
            "term": "penalty",
            "translations_for_term": [
              {
                "target_language": "fr",
                "translation": "sanction"
              }
            ]
          }
        ]
      }
    }
  ]
}
```

The *source* represents the source of the translation. Multiple sources could be returned in the future (currently only IATI is in the triple store).

The *original_term* is just the original term from the request.

## To run the microservice in dev mode:

```
docker run --volume <path-to-your-source-directory>/mu-r-dictionary:/usr/src/app/ext --link mumappingplatform_db_1:database -e RACK_ENV=development -e MU_SPARQL_ENDPOINT=http://192.168.99.100:8890/sparql -p 32888:80 --name mu-r-dictionary semtech/mu-ruby-template:1.2.0-ruby2.1
```

