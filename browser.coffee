module.exports = _ =
  ###*
  *Extends the given object with mixins
  *
  *@method extend
  *@param obj the object to be extended
  *@param mixin the mixins to extend the object
  ###
  extend: (obj..., mixin) ->
    for o in obj
      o[name] = method for name, method of mixin
    return

  ###*
  *Extends the given class with mixins
  *
  *@method include
  *@param class_ the class to be extended
  *@param mixin the mixins to extend the object
  ###
  include: (class_..., mixin) ->
    _.extend inst.prototype, mixin for inst in class_
    return

  ###*
  *Sets default property values
  *
  *@method defaults
  *@param obj the objects whose properties are to be set
  *@param others the default values used to set the properties
  *@returns returns the updated object
  ###
  defaults: (obj, others...) ->
    for other in others
      obj[k] = v for k,v of other when !obj.hasOwnProperty(k)
    obj
    
require('./lib/registry')(_)
require('./lib/queue')(_)
require('./lib/regex')(_)
require('./lib/misc')(_)
