maxInt = 9007199254740992

module.exports = (_) ->
  _.extend _,
  # inspired by <http://tomswitzer.net/2011/02/super-simple-javascript-queue/>
    queue: ->

      first = last = maxInt-10 # for testing wrap-around
      data = []

      fn = (item) ->
        if item is undefined
          if first isnt last
            r = data[first]
            delete data[first]
            first = if first + 1 is maxInt then 0 else first + 1
          return r
        else
          data[last] = item
          last = if last + 1 is maxInt then 0 else last + 1
          return fn

      fn.empty = ->
        first == last

      fn.length = ->
        `var len = first - last; return len < 0 ? -len : len;`
        return

      fn.unshift = (item) ->
        if --first < 0
          first = first + maxInt
        data[first] = item
        return fn

      fn.clear = ->
        last = first
        data = []
        return fn
      
      fn