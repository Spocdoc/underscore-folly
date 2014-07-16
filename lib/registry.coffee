module.exports = (_) ->
  _.extend _,
   
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