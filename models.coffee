mongoose = require 'mongoose'
{Schema} = mongoose
{ObjectId} = Schema
$ = require 'jquery'
{logErr} = require './utils'
{parseCommentPage} = require './scraper'
#{index} = require './indexing' damn you cyclic import
_index = null
index = (args...) ->
  _index = _index or require('./indexing').index
  _index args...


db = mongoose.createConnection "mongodb://localhost/hnsim"


WordScore = new Schema
  word: String
  tfidf: Number


EntrySchema = new Schema
  id: {type: Number, index: true}
  url: String
  title: String
  points: Number
  commentCount: Number
  commentsText: String
  commentsScraped: {type: Boolean, default: false}
  modified: {type: Date, default: Date.now}

  # words extracted from commentsText
  words: {type: [String], index: true}

  # tf-idf scores by word
  scores: {}

  # relevant words for this entry
  relevant: {type: [String], index: true}


Entry = db.model 'Entry', EntrySchema


update = (doc, data) ->
  for att, value of data
    doc[att] = value
  doc


updateOrCreate = (model, lookup, data={}, callback) ->
  model.findOne lookup, (err, doc) ->
    if err then return callback err, null
    if not doc then doc = new model()
    data = $.extend {}, lookup, data
    update doc, data
    doc.save (err) -> callback err, doc


updateOrCreateEntry = (data, callback) ->
  data.modified = Date.now()
  updateOrCreate Entry, {id: data.id}, data, (err, doc) ->
    if err then return callback err
    index doc, true, callback


getOrScrapeEntry = (lookup, callback) ->
  Entry.findOne lookup, logErr (doc) ->
    if doc then return callback null, doc

    # not found, we have to go scrape it
    # we require id be in the lookup, at least for now...
    {id} = lookup
    parseCommentPage id, (err, data) ->
      if err then return callback err
      if not data then return callback 'No data :('
      updateOrCreateEntry data, callback


module.exports = {Entry, db, updateOrCreateEntry, getOrScrapeEntry}
