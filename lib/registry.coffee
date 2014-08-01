module.exports = (_) ->
  _.extend _,
    ###*
    The Registry class implements an associative array of types. 
    Each member of the associative array is itself an array with members of the array corresponding values of the type.
    ###
    Registry: class Registry
      constructor: ->
        @r = {}

      ###*
      This method returns the value of the same type stored in the registry as that passed to the method.
      If the same type is not present in the registry, false is returned.
      @param obj the value whose same type is to be returned.
      @return the value with same type as input if same type is found, false otherwise
      ###
      find: (obj) ->
        return false unless reg = @r[obj.constructor.name]

        for r in reg
          # this ridiculousness is to fix more javascript hangups with "instanceof" for strings and numbers -- "foo" isn't an instanceof String
          if obj instanceof r.type or (r.type is String and typeof obj is 'string') or (r.type is Number and typeof obj is 'number') or (r.type is Boolean and typeof obj is 'boolean')
            return r.d

        false

      ###*
      This method appends the data value to the array with members of the same type. 
      If an array of the constructor type does not exist, it is created.
      @param constructor the type with which the data is associated.
      @param data the value which must appended to the array of the type defined by the constructor parameter,
      @return the array of types with the new member inserted. 
      ###
      add: (constructor, data) ->
        (@r[constructor.name] ||= []).push
          type: constructor
          d: data
        this