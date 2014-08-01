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

regexB64 = /^data:([a-zA-z\/]+);base64,([0-9A-Za-z=+\/]+)$/

module.exports = (_) ->
  _.extend _,

    dataUri:
      ###*
      Returns an object literal containing the mime and base64 value of the parsed string.
      @param str the string to be parsed
      @return the object literal containing the mime and base64 value
      ###
      parse: (str) ->
        if cap = regexB64.exec ''+str
          return {
            'mime': cap[1]
            'b64': cap[2]
          }
      ###*
      Returns the formatted string containg the mime and base64.
      @param mime the mime value to be formatted within the string
      @param base64 the base64 value to be formatted within the string
      @return the formatted string
      ###
      format: (mime, base64) ->
        "data:#{mime};base64,#{base64}"

    ###*
    Formats the string to meet the CSS class naming convention
    @param type the string to be formatted
    @result the formatted string meeting the naming convention
    ###
    makeCssClass: (type) ->
      type.toLowerCase()
        .replace(/\//g, '-')
        .replace(/\x20/g, '_')
        .replace(charsRegex,'')
        .replace(startRegex,'')

    ###*
    Returns the image extension from the mime type
    @param mime the mime type with the image extension, defaults to a blank string
    @return the image extension
    ###
    imgExtension: (mime='') ->
      if cap = /^image\/([a-zA-Z]+)$/.exec mime
        cap[1].toLowerCase()
    
    ###*
    Splits the various sentences from the string and returns them in an array
    @param text the string whose sentences are to be split
    @return the array of sentences
    ###
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

    ###*
    Inserts a backslash before every symbol to convert the symbol within a string to an escape sequence
    @param str the input string to be formatted
    @return the resultant string containing escape sequences
    ###
    regexpEscape: do ->
      regex = /[-\/\\^$*+?.()|[\]{}]/g
      (str) -> return str.replace(regex, '\\$&')

    regexp_punct: "\\(\\[?!.,;\\{\\}:\\]\\)'\"`‘’“”«»‹›"

    # because IE considers \u00a0 to be non-space
    regexpWhitespace: spaceChars
    
    regexp_s: "[#{spaceChars}]"
    
    regexp_S: "[^#{spaceChars}]"

    ###*
    Converts the string to a quote and inserts a backslash character before quote and new line characters
    @param str the input string to be formatted
    @return the resultant quote string
    ###
    quote: do ->
      regexQuotes = /(["\\])/g
      regexNewlines = /([\n])/g

      (str) ->
        if typeof str is 'string'
          '\"'+str.replace(regexQuotes,'\\$1').replace(regexNewlines,'\\n')+'\"'
        else
          str

    ###*
    Returns an array of the names of the arguments of a javascript function
    @param fn the javascript function
    @return an array of argument names
    ###
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

    ###*
    Replaces the reserved character with corresponding character entities
    @param text the reserved character to be replaced
    @param skipEntities boolean value to skip entities or not, defaults to true
    @return the string with character entities in place of reserved characters
    ###
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