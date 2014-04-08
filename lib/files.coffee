fs = require 'fs'
async = require 'async'
hash = require 'hash-fork'
require 'debug-fork'
debugError = global.debug 'error'
mkdirp = require 'mkdirp'
{spawn} = require('child_process')

encodingOption = { encoding: 'utf8' }

readFileCache =
  cacheTimes: {}
  cacheResults: {}

readBinaryCache =
  cacheTimes: {}
  cacheResults: {}

fileHashCache =
  cacheTimes: {}
  cacheResults: {}

regexTypes =
  pdf: /\bpdf\b/i
  txt: /\b(?:ascii|text)\b/i

module.exports = (_) ->
  _.extend _,
    mkdirp: mkdirp

    isText: (src, cb) ->
      src = src.toString('utf-8').substr(0,512)
      return cb null, true unless src
      return cb null, false if ~src.indexOf('\0')

      nonascii = src.match(/[^\x20-\x7f\n\r\t\b]/g)?.length or 0
      total = src.length

      cb null, nonascii < 0.3 * total

    fileType: (src, cb) ->
      done = false
      out = ''

      file = spawn 'file', ['-'], stdio: 'pipe'

      file.on 'error', ->
        unless done
          done = true
          return cb(err or new Error("Can't spawn file"))

      file.stdin.on 'error', (err) ->
      file.stdin.write src, (err) -> file.stdin.end()

      handleChunk = (chunk) ->
        if chunk
          out += chunk.toString 'utf-8'
        return

      file.stdout.on 'data', handleChunk

      file.stdout.on 'end', (chunk) ->
        handleChunk chunk
        unless done
          done = true
          for type, regex of regexTypes
            if regex.test out
              return cb null, type
          return cb null, null

      return


    sameFileSync: (filePath1, filePath2) ->
      _.getInodeSync(filePath1) is _.getInodeSync(filePath2)

    newerThanSync: (lhs, rhs) ->
      try
        lhs = _.getModTimeSync(lhs)
      catch _error
        return false

      try
        rhs = _.getModTimeSync(rhs)
      catch _error
        return true

      lhs > rhs

    getModTime: (filePath, cb) ->
      fs.stat filePath, (err, stat) ->
        return cb(err) if err?
        cb null, stat.mtime.getTime()

    getModTimeSync: (filePath) -> fs.statSync(filePath).mtime.getTime()

    stat: async.memoize fs.stat

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
        try
          mtime = _.getModTimeSync filePath
        catch _error
          debugError "attempt to fileMemoize on a nonexistent file at [#{filePath}]"
          return ''

        return cacheResults[filePath] if cacheTimes[filePath] is mtime
        cacheTimes[filePath] = mtime
        cacheResults[filePath] = fn filePath, args...

  _.extend _,
    readFile: _.fileMemoize ((filePath, cb) -> fs.readFile filePath, encodingOption, cb), readFileCache
    readFileSync: _.fileMemoizeSync ((filePath) -> fs.readFileSync filePath, encodingOption), readFileCache

    readBinary: _.fileMemoize ((filePath, cb) -> fs.readFile filePath, cb), readBinaryCache
    readBinarySync: _.fileMemoizeSync ((filePath) -> fs.readFileSync filePath), readBinaryCache

    fileHash: _.fileMemoize ((filePath, cb) ->
      _.readBinary filePath, (err, buffer) ->
        return cb err if err?
        cb null, hash buffer
    ), fileHashCache

    fileHashSync: _.fileMemoizeSync ((filePath) -> hash _.readBinarySync filePath), fileHashCache

