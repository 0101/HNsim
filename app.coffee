_ = require 'underscore'
express = require 'express'
browserify = require 'browserify'
{browserijade} = require 'browserijade'

settings = require './settings'
findSimilar = require './find-similar'


browserifyFor = (env) ->
  bundle = browserify
    require: ['./client/index']
    filter: if env is 'production' then require 'uglify-js' else null
  bundle.use browserijade "#{__dirname}/templates/includes"
  return bundle


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
  app.use browserifyFor 'production'

app.configure 'development', ->
  app.use express.logger format: 'dev'
  app.use express.errorHandler stack: true
  app.use browserifyFor 'development'


#render = (template, context={}) ->
#  (request, response) -> response.render template, context


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
