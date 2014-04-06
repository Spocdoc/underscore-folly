require 'function_names'
maxInt = 9007199254740992
spaceChars = " \t\r\n\u00a0"

regexSentenceSplit = ///
  ((?:\b(?:etc|i\.?e|e\.?g|viz|[A-Z]))?[\n\.!\?…]+["'\u201c\u201d\u2018\u2019]?)
  (?=$|[^\w,;])
  ///
regexTerminator = /^(?:[\n!\?]|\.(?=[^\.]|$))/
regexCapitalSentence = /^[^a-zA-Z\n]*(?:[A-Z\n]|$)/
regexEndQuote = /["'\u201c\u201d\u2018\u2019]$/

charsRegex = /[^A-Za-z0-9-_]/g
startRegex = /^[^A-Za-z]+/

# some from lodash
module.exports = _ =
  makeCssClass: (type) ->
    type.toLowerCase()
      .replace(/\//g, '-')
      .replace(/\x20/g, '_')
      .replace(charsRegex,'')
      .replace(startRegex,'')

  imgMime: (extension='') ->
    switch extension = extension.toLowerCase()
      when 'jpeg', 'png', 'jp2', 'tiff', 'psd', 'bmp', 'gif'
        "image/#{extension}"
      when 'jpg'
        'image/jpeg'

  nocaseCmp: (lhs, rhs) ->
    # lhs.toLowerCase().localeCompare(rhs.toLowerCase())
    # the below is faster, although not locale-aware
    `(lhs.toLowerCase() < rhs.toLowerCase() ? -1 : 1)`

  splitSentences: (text) ->
    splits = text.split regexSentenceSplit

    sentences = []

    i = 0; iE = splits.length
    while i < iE
      sentence = splits[i]

      j = i + 1

      while j < iE
        next = splits[j]
        sentence += next
        ++j

        break if regexTerminator.test(next) and not regexEndQuote.test(next)

        if j < iE
          next = splits[j]
          break if regexCapitalSentence.test next
          sentence += splits[j++]

      sentences.push sentence
      i = j

    sentences

  tasks: do ->
    recurse = (auto, task, visit) ->
      return unless requires = auto[task]
      delete auto[task] # no cycle detection
      recurse auto, required, visit for required in requires
      visit task, requires

    (auto, visit) ->
      recurse auto, task, visit for task of auto
      return

  startsWith: (string, start) ->
    string.lastIndexOf(start,0) is 0

  endsWith: (string, end) ->
    string.indexOf(end, string.length - end.length) isnt -1

  regexpEscape: do ->
    regex = /[-\/\\^$*+?.()|[\]{}]/g
    (str) -> return str.replace(regex, '\\$&')

  regexp_punct: "\\(\\[?!.,;\\{\\}:\\]\\)'\"`‘’“”«»‹›"

  # because IE considers \u00a0 to be non-space
  regexpWhitespace: spaceChars
  regexp_s: "[#{spaceChars}]"
  regexp_S: "[^#{spaceChars}]"


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

  makeId: do ->
    count = 0
    -> count = if count is maxInt then 0 else count+1

  Registry: class Registry
    constructor: ->
      @r = {}

    find: (obj) ->
      return false unless reg = @r[obj.constructor.name]

      for r in reg
        # this ridiculousness is to fix more javascript hangups with "instanceof" for strings and numbers -- "foo" isn't an instanceof String
        if obj instanceof r.type or (r.type is String and typeof obj is 'string') or (r.type is Number and typeof obj is 'number') or (r.type is Boolean and typeof obj is 'boolean')
          return r.d

      false

    add: (constructor, data) ->
      (@r[constructor.name] ||= []).push
        type: constructor
        d: data
      this

  # inspired by <http://tomswitzer.net/2011/02/super-simple-javascript-queue/>
  queue: ->

    s = e = maxInt-10 # for testing wrap-around
    a = []

    fn = (v) ->
      if v is undefined
        if s isnt e
          r = a[s]
          delete a[s]
          s = if s+1 is maxInt then 0 else s+1
        return r
      else
        a[e] = v
        e = if e+1 is maxInt then 0 else e+1
        return fn

    fn.empty = ->
      s == e

    fn.length = ->
      `var len = s - e; return len < 0 ? -len : len;`
      return

    fn.unshift = (v) ->
      if --s < 0
        s = s + maxInt
      a[s] = v
      return fn

    fn.clear = ->
      e = s
      a = []
      return fn

    fn

  quote: do ->
    regexQuotes = /(["\\])/g
    regexNewlines = /([\n])/g

    (str) ->
      if typeof str is 'string'
        '\"'+str.replace(regexQuotes,'\\$1').replace(regexNewlines,'\\n')+'\"'
      else
        str

  extend: (obj..., mixin) ->
    for o in obj
      o[name] = method for name, method of mixin
    return

  include: (class_..., mixin) ->
    _.extend inst.prototype, mixin for inst in class_
    return

  defaults: (obj, others...) ->
    for other in others
      obj[k] = v for k,v of other when !obj.hasOwnProperty(k)
    obj

  debounce: (func, wait, immediate) ->
    # args are backwards for standard API
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


  argNames: do ->
    regexComments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
    regexFunction = /^function\s*[^\(]*\(([^\)]*)\)\s*\{([\s\S]*)\}$/m
    regexTrim = /^\s*|\s*$/mg
    regexTrimCommas = /\s*,\s*/mg

    return (fn) ->
      if fn.length
        fnText = Function.toString.apply(fn).replace(regexComments, '')
        argsBody = fnText.match(regexFunction)
        argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',').split ','
      else
        []

  unsafeHtmlEscape: do ->
    unsafeEscape =
     '&': '&amp;',
     '<': '&lt;',
     '>': '&gt;'
     '"': "&quot;"
     '\'': "&#39;"

    regexAll = /[&<>"']/g
    regexNoEnt = /(&(?!#?\w+;)|[<>"'])/g

    escapeChar = (ch) -> unsafeEscape[ch] || ch

    (text, skipEntities) ->
      text.replace (if skipEntities then regexNoEnt else regexAll), escapeChar
