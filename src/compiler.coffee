{debug,info} = require 'triage'
util = require 'util'

tokenize = (str) ->

  parse_args = (input) ->
    segments = input.trim().split(/\s+/)
    segments[0] = segments[0].split('.') #if /\./.test(segments[0])
    segments

  parse_filters = (input) ->
    segments = input.trim().split("|")
    [segments[0], segments.slice(1).map((seg) -> seg.trim())]

  # /\{\{(.*?)\}\}|\{(\#|if|else|extends|block)(.*?)\}\s*|\{\/(if|extends|block)(.*?)\}\s*/gi
  regex = ///
      \{(if|\#|\>|else|extends|block|stamp|include)(.*?)\}
    | \{/(if|\#|block|stamp)(.*?)\}
    |  \{(.*?)\}
    | ^\s*\.(if|\#|\>|else|extends|block|stamp|include)(.*?)$\n?
    | ^\s*\./(if|\#|block|stamp)(.*?)$\n?
  ///gim
  index = 0
  lastIndex = null
  result = []
  while (match = regex.exec(str)) != null
    if match.index > index # pre match
      result.push(['text', str.slice(index, match.index)])

    index = regex.lastIndex
    if match[5] # variable
      [args,filters] = parse_filters(match[5])
      [key, params...] = parse_args(args)
      result.push(['vararg', key, params, filters])
    else if match[1] or match[6]
      [tag,args] = if match[1] then [match[1],match[2]] else [match[6], match[7]]
      if tag == 'text'
        result.push(['text', args])
      else
        [key, params...] = parse_args(args)
        result.push([tag, key, params])
    else if match[3] or match[8]
      tag = match[3] or match[8]
      result.push(["end"+tag, null])

  if index < str.length # post match
    result.push(['text', str.slice(index, str.length)])
  regex.lastIndex = 0
  result

processNodes = (tokens, processUntilFn) ->
  output = []
  stamp = false
  while token = tokens.shift()
    break if processUntilFn && processUntilFn(token[0])
    args = token.slice(1)
    args.push(tokens)
    output.push(builders[token[0]].apply(builders, args))
    stamp = output.length if token[0] == 'stamp'
  if output.length > 1
    "multi([#{output.join(',')}], #{stamp})" 
  else if output.length == 1
    output[0]
  else
    "write('')"

# Convert array to eval'able string
strArray = (input) ->
  wrap = input.map (p) -> "'#{p}'"
  "[#{wrap.join(',')}]"

buildQuery = (key, params, calledfrom) ->
  if key.length > 1
    "mget(#{strArray(key)}, #{strArray(params)}, '#{calledfrom}')"
  else
    "get('#{key}', #{strArray(params)}, '#{calledfrom}')"

conditionalQuery = (key, params, calledfrom='') ->
  if key[0][0] != '#'
    "'#{key.join('.')}'"
  else
    key[0] = key[0].slice(1)
    buildQuery(key, params, calledfrom)

builders =
  'vararg': (key, params, filters) ->
    if key.length > 1
      "mgetout(#{strArray(key)}, #{strArray(params)}, #{strArray(filters)})"
    else
      "getout('#{key}', #{strArray(params)}, #{strArray(filters)})"

  'text': (str) ->
    "write('#{escapeJs(str)}')"

  'if': (key,params,tokens) ->
    waselse = false
    body = processNodes tokens, (tag) ->
      if tag=='else' || tag=='endif'
        waselse = true if tag=='else'
        return true
      else
        return false
    elsebody = if waselse
      processNodes tokens, (tag) -> return true if tag=='endif'
    else
      null
    query = buildQuery(key, params, 'if')
    "doif(#{query}, #{body}" + if elsebody then ", #{elsebody})" else ")"

  '#': (key,params,tokens) ->
    query = buildQuery(key, params, 'each')
    body = processNodes tokens, (tag) -> tag=='end#'
    "each(#{query}, #{body})"

  'include': (key,params,tokens) ->
    query = conditionalQuery(key, params, 'include')
    "include(#{query})"

  '>': (key,params,tokens) ->
    query = conditionalQuery(key, params, 'partial')
    "partial(#{query})"

  'stamp': (key, params, tokens) ->
    body = processNodes tokens, (tag) -> tag=='endstamp'
    query = buildQuery(key, params, 'stamp')
    "stamp(#{query}, #{body})"

  'extends': (key, params, tokens) ->
    body = processNodes tokens
    query = conditionalQuery(key, params, 'extends')
    "extend(#{query}, #{body})"

  'block': (key, params, tokens) ->
    body = processNodes tokens, (tag) -> tag=='endblock'
    query = conditionalQuery(key, params, 'block')
    "block(#{query}, #{body})"

BS = /\\/g
CR = /\r/g
LS = /\u2028/g
PS = /\u2029/g
NL = /\n/g
LF = /\f/g
SQ = /'/g
DQ = /"/g
TB = /\t/g

escapeJs = (s) ->
  if typeof s == "string"
    return s
      .replace(BS, '\\\\')
      .replace(DQ, '\\"')
      .replace(SQ, "\\'")
      .replace(CR, '\\r')
      .replace(LS, '\\u2028')
      .replace(PS, '\\u2029')
      .replace(NL, '\\n')
      .replace(LF, '\\f')
      .replace(TB, "\\t")
  return s

exports.compile = (src) ->
  processNodes(tokenize(src))

