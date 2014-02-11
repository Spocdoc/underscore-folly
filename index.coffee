module.exports = _ = require './browser'

require('./lib/files')(_)
require('./lib/transpilers')(_)
require('./lib/watch')(_)

