_ = require 'underscore'
express = require 'express'

settings = require './settings'
findSimilar = require './find-similar'


app = express.createServer()


app.configure ->
  #app.use app.router
  app.use express.bodyParser()
  app.use express.static "#{__dirname}/static", maxAge: 365*24*60*60*1000

  app.set 'views', "#{__dirname}/templates"
  app.set 'view engine', 'jade'
  app.set 'view options', layout: false

app.configure 'production', ->
  app.use express.logger format: ':date :req[X-Real-IP] :method :url :status :response-time ms'
  app.use express.errorHandler stack: false

app.configure 'development', ->
  app.use express.logger format: 'dev'
  app.use express.errorHandler stack: true


app.get '/', (request, response) ->
  respond = (context) ->
    response.render 'index', _.extend {error:null, results:null}, context
  i = request.query.i
  if i?
    if /news\.ycombinator\.com/.test i
      id = /id=(\d+)/.exec(i)?[1]
      if not id
        respond error: "Sorry, couldn't identify an entry from \"#{i}\""
      else
        findSimilar {id}, (error, results) -> respond {error, results}
      return
    else
      respond error: "Sorry, couldn't identify an entry from \"#{i}\""
  respond {}


app.listen settings.port

console.log "listening on port #{settings.port}"
