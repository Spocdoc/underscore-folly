fs = require 'fs'
async = require 'async'

encodingOption = { encoding: 'utf8' }

readFileCache =
  cacheTimes: {}
  cacheResults: {}

module.exports = (_) ->
  _.extend _,
    getModTime: (filePath, cb) ->
      fs.stat filePath, (err, stat) ->
        return cb(err) if err?
        cb null, stat.mtime.getTime()

    getModTimeSync: (filePath) -> fs.statSync(filePath).mtime.getTime()

    getInode: async.memoize (filePath, cb) ->
      fs.stat filePath, (err, stat) ->
        return cb(err) if err?
        cb null, ""+stat.ino

    getInodeSync: do ->
      cache = {}
      (filePath) ->
        return r if r = cache[filePath]
        cache[filePath] = fs.statSync(filePath).ino

    fileMemoize: (fn, cache) ->
      cacheTimes = cache?.cacheTimes || {}
      cacheResults = cache?.cacheResults || {}

      (filePath, args..., cb) ->
        debugger unless cb
        _.getModTime filePath, (err, mtime) ->
          return cb(err) if err?
          return cb(null, cacheResults[filePath]) if cacheTimes[filePath] is mtime

          fn filePath, args..., (err, result) ->
            return cb(err) if err?
            cacheTimes[filePath] = mtime
            cacheResults[filePath] = result
            debugger unless cb
            cb null, result

    fileMemoizeSync: (fn, cache) ->
      cacheTimes = cache?.cacheTimes || {}
      cacheResults = cache?.cacheResults || {}

      (filePath, args...) ->
        mtime = _.getModTimeSync filePath
        return cacheResults[filePath] if cacheTimes[filePath] is mtime
        cacheTimes[filePath] = mtime
        cacheResults[filePath] = fn filePath, args...

  _.extend _,
    readFile: _.fileMemoize ((filePath, cb) -> fs.readFile filePath, encodingOption, cb), readFileCache
    readFileSync: _.fileMemoizeSync ((filePath) -> fs.readFileSync filePath, encodingOption), readFileCache

