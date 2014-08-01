fs = require 'fs'
async = require 'async'
path = require 'path'
convertSourceMap = require 'convert-source-map'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'

module.exports = (_) ->

  ###*
  Compiles the file into javascript and returns the sourcemap.
  ###
  transpilerBase =
    ###*
    Synchronised version of transpilerBase.async
    @param filepath the path of the file to be compiled 
    @result returns the source map
    ###
    sync:
      '.coffee': _.fileMemoizeSync (filePath) ->
        try
          code = _.readFileSync filePath
          coffee = require 'coffee-script'
          obj = coffee.compile code,
            bare: true
            sourceMap: true
            sourceFiles: [filePath]
            generatedFile: [filePath]
          return {
            js: obj['js']
            sourceMap: JSON.parse obj['v3SourceMap']
          }
        catch e
          throw new Error "Error compiling #{filePath}: #{e}"
    ###*
    @param filepath the path of the file to be compiled 
    @param cb the callback function
    ###
    async:
      '.coffee': _.fileMemoize (filePath, cb) ->
        _.readFile filePath, (err, code) ->
          return cb(err) if err?
          coffee = require 'coffee-script'
          try
            obj = coffee.compile code,
              bare: true
              sourceMap: true
              sourceFiles: [filePath]
              generatedFile: [filePath]
            cb null,
              js: obj['js']
              sourceMap: JSON.parse obj['v3SourceMap']
          catch e
            cb(new Error("Error compiling #{filePath}: #{e}"))

  codeTranspilers =
    sync:
      '.js': _.readFileSync
      '.coffee': (filePath) -> transpilerBase.sync['.coffee'](filePath).js

    async:
      '.js': _.readFile
      '.coffee': (filePath, cb) ->
        transpilerBase.async['.coffee'] filePath, (err, obj) -> cb err, obj?.js

  codeSourceMap =
    sync:
      '.coffee': (filePath) ->
        transpilerBase.sync['.coffee'](filePath).sourceMap

    async:
      '.coffee': (filePath, cb) ->
        transpilerBase.async['.coffee'] filePath, (err, obj) -> cb err, obj?.sourceMap

  _.extend _,
    ###*
    Resolves file paths to include the extension of the file. 
    Resolves extensions as js or coffee
    @param filepath the path of the file, may or may not include extension of the file
    @param cb the callback function 
    ###
    resolveExtension: async.memoize (filePath, cb) ->
      return cb null, filePath if path.extname(filePath)
      filePaths = Object.keys(codeTranspilers.async).map((ext) -> "#{filePath}#{ext}")
        .concat Object.keys(codeTranspilers.async).map (ext) -> "#{filePath}/index#{ext}"
      async.detectSeries filePaths, fs.exists, (result) ->
        if !result
          cb new Error("Can't resolve #{filePath}")
        else
          cb null, result
    ###*
    Resolves file paths to include the extension of the file. 
    Resolves extensions as js or coffee. Synchronised version of resolveExtension
    @param filepath the path of the file, may or may not include extension of the file
    @result returns the filepath including the file extension
    ###
    resolveExtensionSync: do ->
      cache = {}
      (filePath) ->
        return filePath if path.extname filePath
        return r if r = cache[filePath]
        for ext of codeTranspilers.sync
          return cache[filePath] = r if fs.existsSync r = "#{filePath}#{ext}"
        for ext of codeTranspilers.sync
          return cache[filePath] = r if fs.existsSync r = "#{filePath}/index#{ext}"
        throw new Error("Can't resolve #{filePath}")

    ###*
    Checks if a transpiler exists for the given file (based on file extension), resolves to a transpiler if it exists
    @param filepath the complete path of the file
    @param cb the callback function 
    ###
    readCode: (filePath, cb) ->
      ext = path.extname filePath
      unless transpiler = codeTranspilers.async[ext]
        return cb new Error("no known transpiler for extension [#{ext}], filePath [#{filePath}]")
      transpiler filePath, cb
    ###*
    Checks if a transpiler exists for the given file (based on file extension), returns a transpiler if it exists.
    Synchronised version of readCode
    @param filepath the complete path of the file
    @result returns a transpiler  
    ###
    readCodeSync: (filePath) ->
      ext = path.extname filePath
      unless transpiler = codeTranspilers.sync[ext]
        throw new Error("no known transpiler for extension [#{ext}], filePath [#{filePath}]")
      transpiler filePath

    ###*
    Generates a source map for the given file
    @param filepath the complete path of the file
    @param cb the callback function 
    ###
    sourceMap: (filePath, cb) ->
      ext = path.extname filePath
      if mapFn = codeSourceMap.async[ext]
        mapFn filePath, cb
      else
        cb null, null
    
    ###*
    Generates a source map for the given file.
    Synchronised version of sourceMap
    @param filepath the complete path of the file
    @result the source map
    ###
    sourceMapSync: (filePath) ->
      codeSourceMap.sync[path.extname filePath]? filePath

    ###*
    Given code with a b64 sourcemap at the end, extracts it and returns the code without the sourcemap and the (object) sourcemap
    @param code contains the code and a source map
    @result separated code and source map
    ###
    extractSourcemap: (code) ->
      code: code.replace convertSourceMap.commentRegex, ''
      map: convertSourceMap.fromSource(code)?.sourcemap


    ###* 
    Takes an array of code, each of which optionally have a trailing b64 sourcemap, and merges them into a single piece of code with a trailing sourcemap
    @param arr an array of code
    @param inlineSources 
    @result merged mapped code containing the code along with a trailing sourcemap
    ###
    mergeMappedCode: (arr, inlineSources) ->
      bundleMap = new SourceMapGenerator file: 'bundle-5298e9128a2f32388dde4970.js'
      bundleCode = ''
      offset = 0

      sources = {}

      for code in arr
        {code,map} = _.extractSourcemap code
        if map
          (new SourceMapConsumer map).eachMapping (m) ->
            sources[m.source] = 1 if m.source
            bundleMap.addMapping
              generated:
                line: m.generatedLine + offset
                column: m.generatedColumn
              original:
                line: m.originalLine
                column: m.originalColumn
              source: m.source
              name: m.name
        bundleCode += code += ';\n'
        offset += code.match(/\r?\n/g).length

      if inlineSources
        for source of sources
          try
            bundleMap.setSourceContent source, _.readFileSync source
          catch _error
            console.error "Error getting source content: #{_error}"
            bundleMap.setSourceContent source, '(error reading source)'

      "#{bundleCode}#{convertSourceMap.fromObject(bundleMap).toComment()}"
