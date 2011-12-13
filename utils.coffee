{log} = require 'util'


makeErrorHandler = (errorCb) ->
  (okCb) -> (err, args...) -> if err then errorCb err else okCb args...


logErr = makeErrorHandler log


module.exports = {makeErrorHandler, logErr}
