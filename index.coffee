module.exports = _ = require './browser'

require('./lib/files')(_)
require('./lib/transpilers')(_)
require('./lib/watch')(_)
require('./lib/queue')(_)

_.extendProps = (obj, mixin) ->
  for prop in Object.getOwnPropertyNames(mixin)
    Object.defineProperty obj, prop, Object.getOwnPropertyDescriptor(mixin, prop)
  obj