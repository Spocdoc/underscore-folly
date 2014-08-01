maxInt = 9007199254740992
module.exports = (_) ->

  _.extend _,
    
    ###*
    Returns image mime type based on image extension
    @param extension the image extension
    @return the image mime
    ###
    imgMime: (extension='') ->
      switch extension = extension.toLowerCase()
        when 'jpeg', 'png', 'jp2', 'tiff', 'psd', 'bmp', 'gif'
          "image/#{extension}"
        when 'jpg'
          'image/jpeg'

    ###*
    Converts 8-bit unsigned integer to base 64 value
    @param bytes the 8-bit unsigned integer input
    @return the base 64 value
    ###
    uint8ToB64: (bytes) ->
      len = bytes.buffer.byteLength
      base64 = ""
      chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
      i = 0
      while i < len
        base64 += chars[bytes[i] >> 2]
        base64 += chars[((bytes[i] & 3) << 4) | (bytes[i + 1] >> 4)]
        base64 += chars[((bytes[i + 1] & 15) << 2) | (bytes[i + 2] >> 6)]
        base64 += chars[bytes[i + 2] & 63]
        i += 3
      if (len % 3) is 2
        base64 = base64.substring(0, base64.length - 1) + "="
      else base64 = base64.substring(0, base64.length - 2) + "=="  if len % 3 is 1
      base64

    ###*
    Case insensitive character by character coomparison of two strings
    @param lhs the string that is being compared
    @param rhs the string being compared to
    @return -1 if first string is lesser than the second, 1 otherwise
    ###
    nocaseCmp: (lhs, rhs) ->
      # lhs.toLowerCase().localeCompare(rhs.toLowerCase())
      # the below is faster, although not locale-aware
      `(lhs.toLowerCase() < rhs.toLowerCase() ? -1 : 1)`

    tasks: do ->
      recurse = (auto, task, visit) ->
        return unless requires = auto[task]
        delete auto[task] # no cycle detection
        recurse auto, required, visit for required in requires
        visit task, requires

      (auto, visit) ->
        recurse auto, task, visit for task of auto
        return

    ###*
    Checks if the given string is present at the start of another string
    @param string the string being checked if it contains the given string at the beginning
    @param start the string to be checked if it is present at the beginning of another string
    @return returns true if start is present at the beginning of string, false otherwise 
    ###
    startsWith: (string, start) ->
      string.lastIndexOf(start,0) is 0
    
    ###*
    Checks if the given string is present at the end of another string
    @param string the string being checked if it contains the given string at the end
    @param end the string to be checked if it is present at the end of another string
    @return returns true if end is present at the ending of string, false otherwise 
    ###
    endsWith: (string, end) ->
      string.indexOf(end, string.length - end.length) isnt -1

    debounceAsync: (fn) ->
      shouldRun = false

      ret = ->
        if ret.running
          shouldRun = true
        else
          run()
        return

      done = (completer) ->
        if shouldRun
          run()
        else
          ret.running = false
          completer?()
        return

      run = ->
        ret.running = true
        shouldRun = false
        fn done
        return

      ret

    ###*
    Returns a number that begins from value 1 is increased by 1 on each call. Is reset to 0 if maximum value is reached
    ###
    makeId: do ->
      count = 0
      -> count = if count is maxInt then 0 else count+1



    ###*
    Invokes a function only if it is not called for a certain wait time
    @param func the function that is invoked
    @param wait the wait time in milliseconds for the function
    @param immediate triggers function on leading edge for if true, triggers on trailing edge if false
    @return the result of the invoked function
    ###
    debounce: (func, wait, immediate) ->
      [func,wait] = [wait,func] if typeof wait is 'function'

      thisArg = result = args = timeoutId = undefined
      if !wait and !immediate and setImmediate
        ->
          args = arguments
          thisArg = this
          unless timeoutId
            timeoutId = 1
            setImmediate =>
              timeoutId = 0
              result = func.apply thisArg, args
          result
      else
        delayed = ->
          timeoutId = null
          result = func.apply thisArg, args unless immediate
          return
        ->
          isImmediate = immediate and !timeoutId
          args = arguments
          thisArg = this

          clearTimeout timeoutId
          timeoutId = setTimeout delayed, wait
          result = func.apply thisArg, args if isImmediate
          result

    ###*
    Throttles the execution of the function such that it is executed at most once per wait time
    @param func the function to be throttled
    @param wait the period in milliseconds over which the function is executed at most once
    @return returns the result of the exexution of the function
    ###
    throttle: `function (func, wait) {
      var args,
          result,
          thisArg,
          lastCalled = 0,
          timeoutId = null;

      function trailingCall() {
        lastCalled = new Date;
        timeoutId = null;
        result = func.apply(thisArg, args);
      }
      var ret = function() {
        var now = new Date,
            remaining = wait - (now - lastCalled);

        args = arguments;
        thisArg = this;

        if (remaining <= 0) {
          clearTimeout(timeoutId);
          timeoutId = null;
          lastCalled = now;
          result = func.apply(thisArg, args);
        }
        else if (!timeoutId) {
          timeoutId = setTimeout(trailingCall, remaining);
        }
        return result;
      };

      ret['runQueued'] = function () {
        if (timeoutId != null) {
          clearTimeout(timeoutId);
          trailingCall();
        }
        return result;
      };
      return ret;
    }`

    startStop: (interval, fn) ->
      thisArg = undefined
      args = null
      id = null

      trailingCall = ->
        fn.apply thisArg, args

      ret = ->
        args = arguments
        thisArg = this
        clearInterval id
        result = fn.apply thisArg, args
        id = setInterval trailingCall, interval
        result

      ret['stop'] = ->
        clearInterval id
        return

      ret