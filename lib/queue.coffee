maxInt = 9007199254740992


module.exports = (_) ->
  _.extend _,
    ###*
    *Inspired by <http://tomswitzer.net/2011/02/super-simple-javascript-queue/>
    *A queue implementation in coffeescript
    *
    ###
    queue: ->

      s = e = maxInt-10 # for testing wrap-around
      a = []

      ###*
      *Enqueues the argument that is passed. Dequeues an item if no argument is passed, returns undefined if it is empty.
      *If no queue exists, it is created and the enqueue/dequeue step is carried out.
      *
      *@method queue
      *@param v the item that is to be enqueued
      *@return for enqueueing, the resultant queue is returned. For dequeueing, the dequeued item is returned
      ###
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

      ###*
      *Checks if the queue is empty
      *
      *@method empty
      *@return true if empty, false otherwise
      ###
      fn.empty = ->
        s == e

      ###*
      *Returns length of the queue
      *
      *@method count
      *@return the queue length
      ###
      fn.count = ->
        len = s - e
        len = if len < 0 then -len else len;
        return len
      
      ###*
      *Prepends an item to the queue
      *
      *@method unshift
      *@param v the value to be prepended to the queue
      *@return the resultant prepended queue is returned
      ###
      fn.unshift = (v) ->
        if --s < 0
          s = s + maxInt
        a[s] = v
        return fn
      
      ###*
      *Clears the queue
      *
      *@method clear
      *@return the cleared queue is returned
      ###
      fn.clear = ->
        e = s
        a = []
        return fn