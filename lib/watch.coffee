fs = require 'fs'
path = require 'path'
require 'debug-fork'
debug = global.debug 'lodash:watch'

DROP_MILLIS = 1500
POLL_MILLIS = 100
CLEAR_MILLIS = 1000

module.exports = (_) ->
  _.extend _,

    ###*
    Used to watch directories for any changes
    @param callback the callback function
    @param dirs is path of directories to be watched. 
    It is optional, can add dirs after by calling returned function on the dir array or string
    @param options the options related to watch the directories
    ###
    watchDirs: (dirs, callback, options) ->
      if typeof dirs is 'function'
        options = callback
        callback = dirs
        dirs = null

      (options ||= {}).persistent ?= false

      cycle = 0
      lastCall = 0

      ret = (dirs) ->
        if dirs
          if dirs.constructor is String
            watchDir dirs
          else
            watchDir filePath for filePath in dirs
        return

      watchDir = (filePath) ->
        try
          dirPath = path.dirname filePath
          unless watcher = ret.watched[inode = _.getInodeSync dirPath]
            debug "watching [#{inode}]: [#{dirPath}]"

            (ret.watched[inode] = watcher = fs.watch dirPath, options).on 'change', (type, fileName) ->
              debug "got hit with ",arguments
              return if ret.callback.running

              now = Date.now()
              if now > lastCall + DROP_MILLIS

                filePath = "#{dirPath}/#{fileName}"
                try
                  return unless _.getModTimeSync(filePath) > lastCall
                catch _error
                  return

                debug "making the call..."
                ret.callback()
              return

          watcher.cycle = cycle
        catch _error

        return

      ret.callback = _.debounceAsync (done) ->
        if callback.length
          callback ->
            lastCall = Date.now()
            done()
        else
          callback()
          lastCall = Date.now()
          done()
        return

      ret.watched = {}

      ret.clear = ->
        clearCycle = cycle
        ++cycle

        setTimeout (->
          for inode, watcher of ret.watched when watcher.cycle is clearCycle
            watcher.close()
            delete ret.watched[inode]
            debug "no longer watching [#{inode}]"
          return
        ), CLEAR_MILLIS

        return

      ret dirs
      ret

  _.extend _,
    ###*
    Watches directories from the required cache
    @param callback the callback function
    @param options the options related to watch the directories
    ###
    watchRequires: (callback, options) ->
      handledRequiresCount = fixedRequiresCount = 0

      reset = (done) ->
        debug "RESET"

        # stop watching all files
        watcher.clear()

        # remove files from cache
        cache = require.cache
        requiredFiles = Object.keys cache
        i = fixedRequiresCount
        j = requiredFiles.length
        delete cache[requiredFiles[i++]] while i < j

        # forget files after fixed count
        handledRequiresCount = fixedRequiresCount

        if callback.length
          callback done
        else
          callback()
          done()
        return

      watcher = _.watchDirs reset, options

      pollRequires = ->
        return if watcher.callback.running

        requiredFiles = Object.keys require.cache
        len = requiredFiles.length
        watcher requiredFiles[handledRequiresCount++] while handledRequiresCount < len

        return

      handledRequiresCount = fixedRequiresCount = Object.keys(require.cache).length
      pollRequires()
      timerId = setInterval pollRequires, POLL_MILLIS
      timerId.unref() # prevent this timer from keeping the process alive

      watcher
