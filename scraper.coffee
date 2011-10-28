http = require 'http'
{log} = require 'util'
fs = require 'fs'
jsdom = require 'jsdom'

{updateOrCreateEntry, db} = require './models'
{makeErrorHandler} = require './utils'


jquerySrc = fs.readFileSync('./jquery-1.6.4.min.js').toString()


print = (args...) -> console.log args...


logErr = makeErrorHandler log


parseNumber = (text) ->
  match = /(\d+)/.exec text
  if match then parseInt match[0] else null


parseEntryHeader = (trTitle, trMeta) ->
  link = trTitle.find '.title a'
  url = link.attr 'href'
  title = link.text()

  commentsLink = trMeta.find 'a[href^="item?id="]'
  if commentsLink.length is 0 then return null

  id = parseNumber commentsLink.attr 'href'
  if id is null then return null

  commentCount = parseNumber(commentsLink.text()) or 0

  points = parseNumber trMeta.find("#score_#{id}").text()

  {id, title, url, points, commentCount}


parsePage = (url, callback) ->
  jsdom.env html: url, src: [jquerySrc], done: (err, window) ->
    callback err, window?.$


parseList = (url, itemCallback, doneCallback) ->
  log "PARSELIST #{url}"
  jsdom.env html: url, src: [jquerySrc], done: logErr (window) ->
    $ = window.$
    mainTable = $('table table').eq 1

    trs = mainTable.find 'tr'

    for [trTitle, trMeta, delim] in (trs[x...x+3] for x in [0...trs.length] by 3)
      data = parseEntryHeader $(trTitle), $(trMeta)
      if data then itemCallback data

    moreLink = mainTable.find 'a:last'
    moreUrl = if moreLink.length is 1
      url = moreLink.attr 'href'
      if url[0] is '/' then url = url[1..]
      "http://news.ycombinator.com/#{url}"
    else
      null

    doneCallback null, moreUrl


HOMEPAGE = 'http://news.ycombinator.com/news'
NEWEST = 'http://news.ycombinator.com/newest'
WAIT = 30 * 1000

scrapeIds = ->
  itemCallback = (data) ->
    log "\tITEM:"
    print data
    updateOrCreateEntry data, logErr()

  cycle = (url) ->
    parseList url, itemCallback, logErr (moreUrl) ->
      if not moreUrl then log "no more url :("

      if moreUrl
        log "Waiting for #{WAIT}"
        setTimeout (->cycle moreUrl), WAIT
  cycle NEWEST


parseHNDaily = (url, callback) ->
  log "PARSE HN DAILY #{url}"
  parsePage url, (err, $) ->
    if err then return callback err
    callback err, (parseNumber $(a).attr('href') for a in $('.commentlink a'))



scrapeHNDaily = (start=33) ->
  indexUrl = 'http://www.daemonology.net/hn-daily/2011.html'

  parsePage indexUrl, logErr ($) ->
    dailyLinks = for a in $('.content a')
      "http://www.daemonology.net/hn-daily/#{$(a).attr 'href'}"

    dailyLinks = dailyLinks[60..dailyLinks.length-start]

    scrapeDaily = ->
      if dailyLinks.length is 0
        return log "No more HNDaily links"

      url = dailyLinks.pop()
      parseHNDaily url, logErr (ids) ->

        scrape = ->
          if ids.length is 0
            log "FINISHED #{url}"
            return setTimeout scrapeDaily, WAIT

          id = ids.shift()
          parseCommentPage id, logErr (data) ->
            if data
              updateOrCreateEntry data, logErr ->
                setTimeout scrape, WAIT
            else
              setTimeout scrape, WAIT
        scrape()

    scrapeDaily()


parseCommentPage = (id, callback) ->
  log "PARSE COMMENT PAGE id #{id}"
  url = "http://news.ycombinator.com/item?id=#{id}"
  parsePage url, (err, $) ->
    if err then return callback err

    [trTitle, trMeta, whatever...] = $('table table').eq(1).find 'tr'
    data = parseEntryHeader $(trTitle), $(trMeta)

    if not data then return callback err, null

    # remove "reply" links
    $('a[href^="reply"]').remove()

    text = ($(comment).text() for comment in $('.comment')).join ' '
    data.commentsText = text
    data.commentsScraped = true
    callback err, data

#parseCommentPage 3125171, logErr (data) ->
#  updateOrCreateEntry data, logErr()

scrapeHNDaily()
