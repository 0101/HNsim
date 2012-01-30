_ = require 'underscore'
async = require 'async'
{Entry} = require './models'

{logErr} = require './utils'


relevancyThreshold = .01


safe = (word) ->
  # make it usable as mongo key
  word.replace(/\./g, '<dot>').replace(/\$/g, '<dollar>')


populateWords = (entry, save=false, cb=->) ->
  text = entry.commentsText
  remove = ['\\.', '\\(', '\\)', '\\?', '!', '"', "'", ","]
  remove.map (s) -> text = text.replace new RegExp(s, 'g'), ''
  text = text.toLowerCase()
  words = text.split /\s+/
  entry.words = words.filter (word) -> word.length > 1
  if save then entry.save cb else cb null, entry
  return entry


populateWordsWhere = (lookup={words: null, commentsScraped: true}) ->
  Entry.find lookup, logErr (docs) ->
    q = []
    docs.map (doc, i) -> q.push (done) ->
      console.log i, doc.title
      populateWords doc, true, logErr (entry) ->
        console.log i, 'finished'
        done()
    async.series q, logErr -> console.log 'done'


populateScores = (entry, save=false, cb=->) ->
  words = entry.words or []
  total = words.length
  entry.scores = {}
  groups = _.groupBy words, (w) ->
    # *sigh*
    if w is 'constructor' then '<constructor>' else w

  Entry.find({words: {$exists: true}}).count (err, docCount) ->
    q = []
    for word, g of groups
      do (word, g) -> q.push (done) ->
        #console.log "Calculating score for #{word}"
        if word is '<constructor>' then word = 'constructor'
        count = g.length
        tf = count/total
        if isNaN tf then return done "le error"
        Entry.find({words: word}).count (err, occurance) ->
          idf = Math.log(docCount/(occurance+1))
          tfidf = tf * idf
          #console.log "\tcount: #{count}, occurance:#{occurance}, tf:#{tf}, idf:#{idf}, tf-idf:#{tfidf}"
          entry.scores[safe word] = tfidf
          done()

    async.series q, (err) ->
      if err then return cb err
      entry.markModified 'scoresDict'
      if save then entry.save cb else cb null, entry


populateRelevant = (entry, save=false, cb=->) ->
  console.log "\npopulating relevant words for '#{entry.title}'"
  wordList = ({word, score} for word, score of entry.scores)
  sortedWordList = _.sortBy wordList, ({score}) -> -score

  entry.relevant = []
  # add all words that are over relevancy threshold, but at least 10 total
  entry.save logErr ->
    #FIXME looks like we have to save or the array won't get rid of the old stuff..
    for {word, score} in sortedWordList
      if score >= relevancyThreshold
        entry.relevant.push word
      else
        if entry.relevant.length < 10
          entry.relevant.push word
        else
          break
    console.log entry.relevant

    if save then entry.save cb else cb null, entry


populateScoresWhere = (lookup={scores: null, commentsScraped: true}) ->
  q = []
  Entry.find lookup, logErr (docs) ->
    for doc in docs
      do (doc) -> q.push (done) ->
        populateScores doc, false, (err, doc) ->
          if err then return done err
          populateRelevant doc, true, done
    console.log 'Queue length:', q.length
    async.series q, logErr -> console.log 'done.'


index = (entry, save=false, cb=->) ->
  console.log "indexing '#{entry.title}'"
  entry = populateWords entry
  populateScores entry, false, (err, entry) ->
    if err then return cb err
    populateRelevant entry, save, cb


module.exports = {index}


if process.argv[2] is 'populatewords'
  populateWordsWhere()

if process.argv[2] is 'repopulatewords'
  populateWordsWhere commentsScraped: true

if process.argv[2] is 'populatescores'
  populateScoresWhere()

if process.argv[2] is 'repopulatescores'
  populateScoresWhere commentsScraped: true
