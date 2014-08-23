path = require 'path'
fs = require 'fs'
#require 'debug-fork'
#debug = global.debug 'resolve'

paths = {}
resolutions = {}
pkgOrigins = {}
packages = {}
regexSplit = if process.platform is 'win32' then /[\/\\]/ else /\//
extensions = require.extensions

resolveAt = (trailingSlash, fullPath) ->
  #debug "--> #{fullPath}"

  if !trailingSlash
    try
      return fullPath if !fs.statSync(fullPath).isDirectory()
    catch _error # because fs.existsSync just calls stat and catches the exception
    for ext of extensions
      return p if fs.existsSync p = "#{fullPath}#{ext}"

  if fs.existsSync pkgPath = "#{fullPath}/package.json"
    if pkgPath = (packages[pkgPath] ||= JSON.parse fs.readFileSync pkgPath).main
      if result = resolveAt (pkgPath.slice(-1) is '/'), path.resolve fullPath, pkgPath
        return  result

  for ext of extensions
    return p if fs.existsSync p = "#{fullPath}/index#{ext}"

  return

module.exports = (_) -> 
  _.extend _,
   resolve : (requiredPath, filePath) ->
    #debug "searching for #{requiredPath} from #{filePath}"
    abs = 0 is slash = requiredPath.indexOf '/'

    cacheKey = if abs then requiredPath else if (relative = requiredPath.substr(0,2) in ['./','..']) then "#{filePath}:#{requiredPath}" else requiredPath
    return result if (result = resolutions[cacheKey]) and fs.existsSync result

    trailingSlash = requiredPath.slice(-1) is '/'

    if abs
      return resolutions[cacheKey] = result if result = resolveAt trailingSlash, requiredPath
    else
      if filePath?
        filePath = path.dirname path.resolve filePath
      else
        filePath = process.cwd()

      if relative
        return resolutions[cacheKey] = result if result = resolveAt trailingSlash, path.resolve filePath, requiredPath
      else
        pkgName = if ~slash then requiredPath.substr 0, slash else requiredPath
        if origin = pkgOrigins[pkgName]
          return resolve requiredPath, origin if origin isnt "#{filePath}/origin"
        else
          pkgOrigins[pkgName] = "#{filePath}/origin"

        unless arr = paths[filePath]
          paths[filePath] = arr = []
          parts = filePath.split regexSplit
          i = parts.length
          while --i >= 0 when parts[i] isnt 'node_modules'
            arr.push parts.slice(0, i + 1).concat('node_modules').join(path.sep)
          if p = process.env.NODE_PATH
            arr.push p.split(':')...

        for part in arr
          return resolutions[cacheKey] = result if result = resolveAt trailingSlash, path.resolve part, requiredPath

    throw new Error "Cannot find module '#{requiredPath}' from #{filePath}"