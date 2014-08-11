fs = require 'fs'
path = require 'path'
async = require 'async'
ug = require 'uglify-js-fork'
resolve = require 'resolve-fork'

regexNonNameChars = /[^a-zA-Z0-9_]/g
varIndex = 0

module.exports = (_) ->
  _.extend _,

    ###*
    *Mangles name of given node
    *
    *@method mangleNode
    *@param node the node whose name is to be mangled node
    *@return the node along with its mangled name
    ###  
    mangleNode: (node) ->
      if node.thedef?.closurifyName
        node.debugName = node.name
        node.name = node.thedef.closurifyName.name
        delete node.thedef
        node
      else if node instanceof ug.AST_VarDef and node.name.thedef?.closurifyName
        {name, start, end} = node.name
        newName = node.name = node.name.thedef.closurifyName.clone()
        newName.debugName = name
        newName.start = start
        newName.end = end
        return # because the RHS could have other symbols to mangle

    mangle: do ->
      changeVarNames = (ast) ->
        ast.transform walker = new ug.TreeTransformer (node, descend) ->
          ret if ret = _.mangleNode node
        ast
      (ast) ->
        ast.figure_out_scope()

        ast.walk new ug.TreeWalker (node, descend) ->
          if node.TYPE is 'Toplevel'
            node.variables?.each (v) ->
              v.closurifyName =
                new ug.AST_SymbolConst
                  name: _.makeName(v.name)
            node

        changeVarNames ast

  _.extend _,
    
    transformFunctions: (fn) ->
      walker = new ug.TreeTransformer (node, descend) ->
        descend node, this
        if node.TYPE is 'Function' and changed = fn node
          changed
        else
          node

    transformRequires: (ast, fn) ->
      ast.figure_out_scope()
      ast.transform new ug.TreeTransformer (node) -> fn node if _.isRequire node
      return

    deepClone: do ->
      transform = new ug.TreeTransformer (node, descend) ->
        node = node.clone()
        descend node, this
        node
      (ast) -> ast.transform transform

    # code is optional
    getAst: _.fileMemoizeSync (filePath, code) ->
      ug.parse (code ? _.readCodeSync(filePath)), filename: filePath

    getMangledAst: _.fileMemoizeSync (filePath, code) ->
      _.mangle _.deepClone _.getAst filePath, code

    ###*
    *Gets the paths using the require function from the AST. 
    *
    *@method transformFunctions
    *@param fn the function to be transformed
    *@return the node along with its mangled name
    ###
    getAstRequiresSync: (ast) ->
      requiredPaths = []
      ast.figure_out_scope()
      ast.walk new ug.TreeWalker (node) ->
        if _.isRequire node
          requiredPaths.push _.resolveRequireCall node
          node
      requiredPaths

  _.extend _,
    getCodeRequires: (code) ->
      _.getAstRequiresSync ug.parse code

    getRequiresSync: do ->
      cacheTimes = {}
      cache = {}
      (filePath) ->
        unless cacheTimes[filePath] is mtime = _.getModTimeSync(filePath)
          requiredPaths = []
          ast = ug.parse(_.readCodeSync(filePath))
          ast.figure_out_scope()
          ast.walk new ug.TreeWalker (node) ->
            if _.isRequire node
              requiredPaths.push node.args[0].value
              node
          cache[filePath] = requiredPaths
          cacheTimes[filePath] = mtime
        else
          requiredPaths = cache[filePath]

        # resolve every time since resolved path could change. (these are also cached)
        ret = []
        ret[i] = resolve requiredPath, filePath for requiredPath, i in requiredPaths
        ret

    isContainer: (node) ->
      body = node.body || node.definitions
      Array.isArray(body) || node.car

    ###*
    *Checks if the node uses the require statement
    *
    *@method isRequire
    *@param node the node to be checked
    *@return true if it does, false otherwise
    ###
    isRequire: (node) ->
      if (node instanceof ug.AST_Call) and (node.args[0] instanceof ug.AST_String)
        # module.require('foo')
        if (e1 = node.expression) instanceof ug.AST_PropAccess and
            (e2 = e1.expression).TYPE is 'SymbolRef' and
            e2.undeclared?() and e2.name is 'module' and
            (e1.property.value || e1.property) is 'require'
          return true

        # require('foo')
        if node.expression.TYPE is 'SymbolRef' and node.expression.name is 'require' and node.expression.undeclared?()
          return true

      return false

    ###*
    *Checks if the node uses the module.exports statement
    *
    *@method isModuleExports
    *@param node the node to be checked
    *@return true if it does, false otherwise
    ###
    isModuleExports: (node) ->
      (node instanceof ug.AST_PropAccess) and
        node.expression.TYPE is 'SymbolRef' and
          node.expression.undeclared?() and
          node.expression.name is 'module' and
          (node.property.value || node.property) is 'exports'

    isExpandableDo: (node) ->
      node instanceof ug.AST_Call and node.expression instanceof ug.AST_Lambda and !(node.args?.length) and !(node.expression.argnames?.length)

    makeName: (prefix) -> "#{prefix || ''}__#{++varIndex}"
    
    ###*
    *Converts the filepath to a variable name
    *
    *@method fileToVarName
    *@param filePath the path to be converted
    *@return the variable name
    ###
    fileToVarName: (filePath) ->
      if name = path.basename filePath, path.extname filePath
        name = path.basename path.dirname filePath if name is 'index'
        name = name.replace regexNonNameChars, ''
        newName = ''
        for word in name.split '_' when word
          newName += word.charAt(0).toUpperCase() + word.substr(1)
        newName
      else
        ''
    
    ###*
    *Attempts to resolve the require call
    *
    *@method resolveRequireCall
    *@param reqCall the require to be resolved
    *@return the resolved require, an error otherwise
    ###
    resolveRequireCall: (reqCall) ->
      try
        resolve reqCall.args[0].value, reqCall.start.file
      catch _error
        console.error "Error while resolving require path #{reqCall.args[0].value} from #{reqCall.start.file}"
        throw _error

    # this is intentionally done with strings rather than the AST because closure
    # will remove function wrappings
    wrapCodeInFunction: (code) ->
      "(function(){#{code}}());"

    wrapASTInFunction: do ->
      wrapperText = "(function (){}())"
      (ast) ->
        parsed = ug.parse wrapperText
        ast.transform new ug.TreeTransformer (node) ->
          body = node.body.splice 0
          parsed.transform _.transformFunctions (fnNode) ->
            fnNode.body = body
            fnNode
          node.body.push parsed
          node
        ast

    unwrapASTFunction: (ast) ->
      body = null

      ast.transform new ug.TreeTransformer (node, descend) ->
        if node.TYPE is 'Toplevel'
          descend node, this
          node.body = body
          node
        else if node.TYPE is 'Function'
          body = node.body
          node
      ast

    ###*
    *Merges the sets of nodes 
    *
    *@method merge
    *@param dst one set of nodes
    *@param src another set of nodes
    *@return the merged set of nodes
    ###
    merge: (dst, src) ->
      if dst is src
        return dst
      else if !dst?
        return src
      else if !src?
        return dst

      if nodes = src.body
        (dst.body ||= []).push nodes...

      dst


    # removed is optional array of removed nodes
    removeASTExpressions: (removed, fn) ->
      if typeof removed is 'function'
        fn = removed
        removed = undefined

      target = undefined
      container = undefined
      toSplice = [] # vardef, assigns or simple statements to remove from body/definitions

      # "target" is the thing to remove. "container" is the thing that contains the
      # target (so it's the node that's mutated)

      maybeTarget = (node) ->
        container is walker.parent()

      walker = new ug.TreeTransformer (node, descend) ->
        doDescend = undefined

        if thisContainer = _.isContainer node
          doDescend = true
          [prevContainer, container] = [container, node]
          [prevSplice, toSplice] = [toSplice, []]

        if thisTarget = maybeTarget node
          doDescend = true
          [prevTarget, target] = [target, node]

        if target and fn(node)
          removed.push target
          toSplice.push target
          doDescend = false

        return if doDescend is undefined

        descend node, this if doDescend

        if thisTarget
          target = prevTarget

        if thisContainer
          container = prevContainer
          [thisSplice, toSplice] = [toSplice, prevSplice]
          body = (node.body || node.definitions)

          for elem in thisSplice # TODO slow O(n^2) operation
            return new ug.AST_EmptyStatement if elem is node

            if body
              if !~(index = body.indexOf(elem))
                throw new Error("removeASTExpressions algorithm bug")
              body.splice(index, 1)
            else if node.car is elem
              node = node.cdr
            else
                throw new Error("removeASTExpressions algorithm bug")

          if body && !body.length && node.TYPE is 'Var'
            return new ug.AST_EmptyStatement

        node