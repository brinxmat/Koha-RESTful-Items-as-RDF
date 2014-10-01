#!/usr/bin/env ruby
# encoding: utf-8

# Transform item data from Biblibre's Koha-RESTful API to RDF
# Author: Rurik Greenall (2014-09-16)

# USAGE: ruby -r "./RESTfulAPIKohaItemsAsRDF.rb" -e "RESTfulAPIKohaItemsAsRDF.rdf_from_title_number '664017'"
# where 664017 is a biblioitemnumber / title number

# Assumes that @itemsListUrl points to a Koha instance with Biblibre's RESTful API installed
# Returns an RDF object with a rdf:Bag containing the item data

# There are some obvious issues with this approach as it isn't quite clear what we are returning here
# at best we are talking about a Koha-determined collection of data and not a commonly recognised category 
# for bibliographic data

require 'json'
require 'rdf'
require 'rdf/raptor'
require 'net/http'

class RESTfulAPIKohaItemsAsRDF

  @base = "http://deichman.no/kohaitems/"
  @itemBase = "http://deichman.no/items/"
  @itemlistUrl = "http://knakk:8080/cgi-bin/koha/rest.pl/biblio/__id__/items"

  def self.load_data (id)
  	return JSON.parse (Net::HTTP.get(URI(@itemlistUrl.gsub(/__id__/,id))))
  end

  def self.rdf_from_title_number (id)

    bf = RDF::Vocabulary.new("http://bibframe.org/vocab/")
    deichman = RDF::Vocabulary.new("http://deichman.no/vocab/")
    frbr = RDF::Vocabulary.new("http://purl.org/vocab/frbr/core#")
    holding = RDF::Vocabulary.new("http://purl.org/ontology/holding#")

    graph = RDF::Graph.new 
    s = RDF::URI.new(@base + "x" + id)

    for k in load_data id do

      branch = RDF::URI.new( :scheme => 'http', :host => 'deichman.no', :path => 'branch/' + k['homebranch'] )
      uri = RDF::Node.new
      graph.insert << [s, RDF.Bag, uri]
      graph.insert << [uri, RDF.type, frbr.Item]
      graph.insert << [uri, holding.label, k['itemcallnumber']]
      graph.insert << [uri, deichman.barcode, k['barcode']]
      graph.insert << [uri, deichman.heldBy, branch]
      graph.insert << [uri, deichman.itemnumber, k['itemnumber']]

      if ( k['onloan'].to_s == "" ) 
      	graph.insert << [uri, bf.circulationStatus, deichman.Available]
      else
      	graph.insert << [uri, bf.circulationStatus, deichman.OnLoan]      	
      end

      if ( k['reserves'].to_s != "" ) 
        graph.insert << [uri, deichman.reserves, k['reserves']]
      end

      if ( k['date_due'].to_s != "" ) 
        graph.insert << [uri, deichman.dueDate, k['date_due']]
      end
    end
    output = RDF::Writer.for(:turtle).buffer do |writer|
      writer << graph
    end
    puts output
  end
end
