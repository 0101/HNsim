$ = require 'jquery-browserify'
# assign jQuery to the window so Backbone can pick it up...
window.jQuery = $
{renderFile} = require 'browserijade'


{log} = require './utils'


$(document).ready ->
  log 'document ready'


