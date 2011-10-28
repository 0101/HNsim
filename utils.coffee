

makeErrorHandler = (errorCb) ->
  (okCb) -> (err, args...) -> if err then errorCb err else okCb args...


module.exports = {makeErrorHandler}
