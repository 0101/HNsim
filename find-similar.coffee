_ = require 'underscore'
ObjectId = require('mongoose').Types.ObjectId
{getOrScrapeEntry} = require './models'
{index} = require './indexing'
{Entry} = require './models'



getRelevantScores = (entry) ->
  entry.relevant.reduce (dict, word) ->
    dict[word] = entry.scores[word]
    dict
  , {}


ScoresList = (entry, words) ->
  words ?= entry.relevant
  _.sortBy words.map((w) -> word: w, score: String(entry.scores[w] *100)[..5]),
    ({score}) -> -score


similarity = (s1, s2, common) ->
  #console.log "s1:", s1, "s2:", s2, "common:",common
  common.length * common.reduce ((result, word) -> result + s1[word] * s2[word]), 0


commonWords = (r1, r2) -> r1.filter (w) -> w in r2


processResult = (words, relevantScores, entry) ->
  #console.log "processResult, words:", words, "relevantScores:", relevantScores
  entryScores = getRelevantScores entry

  common = commonWords words, entry.relevant

  rating = similarity relevantScores, entryScores, common

  url = entry.url
  if url[...4] isnt 'http' then url = "http://news.ycombinator.com/#{url}"

  title: entry.title
  url: url
  commentsUrl: "http://news.ycombinator.com/item?id=#{entry.id}"
  rating: String(rating * 1000)[..5] # just to make it look prettier...
  common: ScoresList(entry, common)


findSimilar = (entry, callback) ->

  # Find all entries with some common relevant words
  lookup = relevant: {$in: entry.relevant}, _id: {$ne: entry._id}
  fields = scores:1, title:1, relevant:1, url:1, id:1
  Entry.find lookup, fields, (err, docs) ->
    if err then return callback err
    if not docs?.length? then return callback "Sorry, no results"

    relevantScores = getRelevantScores entry
    console.log relevantScores

    results = docs.map (doc) ->
      processResult entry.relevant, relevantScores, doc

    results = _.sortBy results, ({rating}) -> -rating

    callback err,
      entry: entry
      relevant: ScoresList(entry)
      commentsUrl: "http://news.ycombinator.com/item?id=#{entry.id}"
      results: results[...10], null, 2





module.exports = ({id}, callback) ->

  getOrScrapeEntry {id}, (err, entry) ->
    if err then return callback err
    if entry.relevant?.length?
      findSimilar entry, callback
    else
      index entry, true, (err, entry) ->
        if err then return callback err
        findSimilar entry, callback




