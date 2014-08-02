fs = require 'fs'
async = require 'async'
# hash = require 'hash-fork'
# require 'debug-fork'
# debugError = global.debug 'error'
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
    ###*
    *Checks if the object is text
    *
    *@method isText
    *@param src the object to be checked
    *@param cb the callback function
    ###
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

    ###*
    *Checks if files have same inode
    *
    *@method sameFileSync
    *@param filePath1 the path of a file
    *@param filePath2 the path of a file
    *@return returns true if same inode, false otherwise
    ###
    sameFileSync: (filePath1, filePath2) ->
      _.getInodeSync(filePath1) is _.getInodeSync(filePath2)

    ###*
    *Checks if the first file has been modified later than the second file
    *
    *@method newerThanSync
    *@param lhs the path of the first file 
    *@param lhs the path of the seccond file 
    *@return returns true if first file is modified later, false otherwise
    ###
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
    
    ###*
    *Gets the latest time of modification of the file
    *
    *@method getModTime
    *@param filePath the path of the file
    *@param cb the callback function
    ###
    getModTime: (filePath, cb) ->
      fs.stat filePath, (err, stat) ->
        return cb(err) if err?
        cb null, stat.mtime.getTime()

    ###*
    *Gets the latest time of modification of the file. Synchronised version of getModTime
    *
    *@method getModTimeSync
    *@param filePath the path of the file
    *@return the latest modified time of the file
    ###
    getModTimeSync: (filePath) -> fs.statSync(filePath).mtime.getTime()

    stat: async.memoize fs.stat
    
    ###*
    *Gets the inode of the file
    *
    *@method getInode
    *@param filePath the path of the file
    *@param cb the callback function
    ###
    getInode: async.memoize (filePath, cb) ->
      fs.stat filePath, (err, stat) ->
        return cb(err) if err?
        cb null, ""+stat.ino

    ###*
    *Gets the inode of the file Synchronised version of geetInode
    *
    *@method getInodeSync
    *@param filePath the path of the file
    *@return the inode of the file
    ###
    getInodeSync: do ->
      cache = {}
      (filePath) ->
        return r if r = cache[filePath]
        cache[filePath] = fs.statSync(filePath).ino

    ###*
    *File memoization, stores the result of most recent call of the function fn. 
    *If no modification has been carried out on the file till last call, most recent result is used 
    *
    *@method fileMemoize
    *@param fn the function call used on the file whose result is stored
    *@param cache the most recent result as well as time of the last modification of the file
    ###
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

    ###*
    *File memoization, stores the result of most recent call of the function fn. 
    *If no modification has been carried out on the file till last call, most rec/ent result is used.
    *Synchronized version of fileMemoize
    *
    *@method fileMemoizeSync
    *@param fn the function call used on the file whose result is stored
    *@param cache the most recent result as well as time of the last modification of the file
    ###
    fileMemoizeSync: (fn, cache) ->
      cacheTimes = cache?.cacheTimes || {}
      cacheResults = cache?.cacheResults || {}

      (filePath, args...) ->
        try
          mtime = _.getModTimeSync filePath
        catch _error
          # debugError "attempt to fileMemoize on a nonexistent file at [#{filePath}]"
          return ''

        return cacheResults[filePath] if cacheTimes[filePath] is mtime
        cacheTimes[filePath] = mtime
        cacheResults[filePath] = fn filePath, args...

  _.extend _,
    readFile: _.fileMemoize ((filePath, cb) -> fs.readFile filePath, encodingOption, cb), readFileCache
    readFileSync: _.fileMemoizeSync ((filePath) -> fs.readFileSync filePath, encodingOption), readFileCache

    readBinary: _.fileMemoize ((filePath, cb) -> fs.readFile filePath, cb), readBinaryCache
    readBinarySync: _.fileMemoizeSync ((filePath) -> fs.readFileSync filePath), readBinaryCache

    # fileHash: _.fileMemoize ((filePath, cb) ->
    #   _.readBinary filePath, (err, buffer) ->
    #     return cb err if err?
    #     cb null, hash buffer
    # ), fileHashCache

    # fileHashSync: _.fileMemoizeSync ((filePath) -> hash _.readBinarySync filePath), fileHashCache

