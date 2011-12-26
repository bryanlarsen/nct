_            = require 'underscore'
fa           = require 'fa'
_.str        = require 'underscore.string'

compiler     = require './compiler'

nct = {}
nct.tokenize = compiler.tokenize
nct.compile  = compiler.compile

stampFn = (name, command) ->
  re = /\{(.+?)\}/g
  slots = []
  while (match = re.exec(name))
    slots.push match[1]

  return (context, callback) ->
    ctx = if context instanceof Context then context else new Context(context)

    filled_slots = {}
    fa.each slots, ((key, callback) ->
      ctx.get key, [], (err, result) ->
        filled_slots[key] = result
        callback()
    ), (err) ->
      stamped_name = name.replace /\{(.+?)\}/g, (matched, n) -> filled_slots[n]

      command ctx, (err, result) ->
        callback(err, result, stamped_name, ctx.deps)

nct.stamp = (name, context, callback) ->
  nct.load name, null, (err, tmpl) ->
    ctx = new Context(context)
    ctx.stamp = true
    tmpl ctx, (err, result) ->
      callback(err, stampFn(name, result), ctx.deps, ctx.stamping)

# Render template passed in as source template
nct.renderTemplate = (source, context, name, callback) ->
  if !callback
    callback = name
    name = null

  tmpl = nct.loadTemplate(source, name)
  nct.doRender tmpl, context, callback

nct.loadTemplate = (tmplStr, name=null) ->
  try
    tmpl = nct.compile(tmplStr)
  catch e
    console.error "Error loading nct template: #{name}"
    console.error e
    throw e
  nct.register(tmpl, name)

nct.removeTemplate = (name) ->
  if nct.reverse_mapping[name]
    template_name = nct.reverse_mapping[name]
    delete nct.reverse_mapping[name]
    delete nct.template_mapping[template_name]
    delete nct.templates[template_name]
  else
    filename = nct.template_mapping[name]
    delete nct.reverse_mapping[filename]
    delete nct.template_mapping[name]
    delete nct.templates[name]

nct.compileToString = (tmplStr, name) ->
  tmpl = nct.compile(tmplStr)
  "nct.register(unescape('#{escape(tmpl)}'), unescape('#{escape(name)}'))\n"

nct.clear = ->
  nct.templates = {}
  nct.template_mapping = {}


Context = require('./base')(nct, _, fa)

module.exports = nct
module.exports.Context = Context
