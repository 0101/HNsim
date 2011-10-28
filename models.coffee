mongoose = require 'mongoose'
{Schema} = mongoose
{ObjectId} = Schema
$ = require 'jquery'


db = mongoose.createConnection "mongodb://localhost/hnsim"


EntrySchema = new Schema
  id: {type: Number, index: true}
  url: String
  title: String
  points: Number
  commentCount: Number
  commentsText: String
  commentsScraped: {type: Boolean, default: false}
  modified: {type: Date, default: Date.now}

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
  updateOrCreate Entry, {id: data.id}, data, callback


module.exports = {Entry, db, updateOrCreateEntry}
