require "active_support/core_ext/array"

module Wikidata
  class Entity < Wikidata::HashedObject

     def self.find_all query

      found_objects = []

      query = {
        action: 'wbgetentities',
        sites: 'enwiki',
        format: 'json'
      }.merge(Wikidata.default_languages_hash).merge(query)

      ids = query[:ids] || []
      titles = query[:titles] || []

      # Split IDs and titles
      ids = ids.split("|") if ids && ids.class == String
      titles = titles.split("|") if titles && titles.class == String

      # Reject already cached values
      fetchable_ids = ids.reject do |id|
        if val = IdentityMap.cached_value(id)
          found_objects << val
          true
        else
          false
        end
      end
      fetchable_titles = titles.reject do |title|
        if val = IdentityMap.cached_value(title)
          found_objects << val
          true
        else
          false
        end
      end

      # Fetch by IDs
      if fetchable_ids.length > 0
        fetchable_ids.in_groups_of(50, false) do |group|
          found_objects.concat query_and_build_objects(query.merge(ids: group.join("|")))
        end
      end

      # Fetch by titles
      if fetchable_titles.length > 0
        fetchable_titles.in_groups_of(50, false) do |group|
          found_objects.concat query_and_build_objects(query.merge(titles: group.join("|")))
        end
      end

      found_objects
    end

    def self.wikify_string string
      if string
        string[0].upcase + string[1..string.size].gsub(' ', '_')
      end
    end

    def self.query_and_build_objects(query)
      response = HTTParty.get('http://www.wikidata.org/w/api.php', {query: query})
      # puts "Getting: #{query}"
      response['entities'].map do |entity_id, entity_hash|
        item = new(entity_hash)
        IdentityMap.cache!(entity_id, item)
        item
      end
    end

    def self.find_all_by_id id, query = {}
      find_all({ids: id}.merge(query))
    end

    def self.find_by_id *args
      find_all_by_id(*args).first
    end

    def self.find_all_by_title title, query = {}
      find_all({titles: title}.merge(query))
    end

    def self.find_by_title *args
      response = find_all_by_title(*args).first
      
      if response.has_content?
        response
      else
        str = wikify_string(args.first)
        find_all_by_title(*[str, args[1..args.size]].flatten!).first
      end

    end

    def inspect
      "<#{self.class.to_s} id=#{id}>"
    end

    def delocalize(hash, locale = I18n.default_locale)
      return nil unless hash
      h = hash[locale.to_s]
      h ? h.value : nil
    end

    def label(*args)
      delocalize self.data_hash.labels, *args
    end

    def description(*args)
      delocalize self.data_hash.descriptions, *args
    end

  end
end
