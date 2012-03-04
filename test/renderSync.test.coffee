if !window?
  fs = require 'fs'
  path = require 'path'
  fa = require 'fa'
  nct = require('../lib/nct').sync
  _ = require 'underscore'
  e = require('chai').expect
else
  window.e = chai.expect


describe "Sync Context", ->
  it "New Context", ->
    ctx = new nct.Context({"title": "hello"}, {})
    e(ctx.get('title')).to.equal "hello"

  it "Context push", ->
    ctx = new nct.Context({"title": "hello"}, {})
    ctx = ctx.push({"post": "Hi"})
    e(ctx.get('title')).to.equal "hello"
    e(ctx.get('post')).to.equal "Hi"

  it "Context with synchronous function", ->
    ctx = new nct.Context({"title": () -> "Hello World"}, {})
    e(ctx.get('title')).to.equal "Hello World"

  it "Context.get from null", ->
    ctx = new nct.Context(null)
    e(ctx.get('title')).to.equal ""

  contextAccessors = [
    [["title"], {title: "Hello"}, "Hello"]
    [["post","title"], {post: {title: "Hello"}}, "Hello"]
    [["post","blah"], {post: ["Hello"]}, undefined]
    [["post","blah","blah"], {post: ["Hello"]}, ""]
    [["post","isnull","blah"], {post: null}, null]
  ]

  contextAccessors.forEach ([attrs, context, expected]) ->
    it "Context accessors #{attrs}", ->
      ctx = new nct.Context(context, {})
      e(ctx.mget(attrs)).to.equal expected


# cbGetFn = (cb, ctx, params) -> ctx.get(params[0], [], cb)

describe "Sync Compile and Render", ->
  nct.filters.upcase = (v) -> v.toUpperCase()
  nct.filters.question = (v) -> v+'?'


  compileAndRenders = [
    ["Hello", {}, "Hello"]
    ["Hello {title}", {title: "World!"}, "Hello World!"]
    ["Hello { title }", {title: "World!"}, "Hello World!"]
    ["Hello {person.name}", {person: {name: "Joe"}}, "Hello Joe"]
    ["Hello {person.name}", {person: (-> {name: "Joe"})}, "Hello Joe"]
    ["Hello {person.name}", {person: {name: "<i>Joe</i>"}}, "Hello &lt;i&gt;Joe&lt;/i&gt;"]
    ["Hello {person.name}", {person: (-> {name: (-> "Joe")})}, "Hello Joe"]
    ["{if post}{post.title}{/if}", {post: {title: 'Hello'}}, "Hello"]
    ["{# post}{title}{/#}", {post: {title: 'Hello'}}, "Hello"]
    ["{if doit}{name}{/if}", {doit: true, name: "Joe"}, "Joe"]
    ["{if nope}{name}{/if}", {nope: false, name: "Joe"}, ""]
    ["{if doit}{name}{else}Noope{/if}", {doit: false, name: "Joe"}, "Noope"]
    ["{# posts}{title}{/#}", {posts: [{'title': 'Hello'},{'title':'World'}]}, "HelloWorld"]
    ["{# person}{name}{/#}", {person: {'name': 'Joe'}}, "Joe"]
    ["{# person}{/#}", {person: {'name': 'Joe'}}, ""]
    ["{# person}{else}Nope{/#}", {person: []}, "Nope"]
    ["{if post}{post.title}{/if}", {post: {title: 'Hello'}}, "Hello"]
    ["{# person}{name}{/# person}", {person: {'name': 'Joe'}}, "Joe"]
    ["{- noescape }", {noescape: "<h1>Hello</h1>"}, "<h1>Hello</h1>"]
    ["{- post.title}", {post: {title: "<h1>Hello</h1>"}}, "<h1>Hello</h1>"]
    ["{ title | upcase}", {title: 'hello world'}, "HELLO WORLD"]
    ["{ title | upcase | question}", {title: 'hello'}, "HELLO?"]
    ["{ escape }", {escape: "<h1>Hello</h1>"}, "&lt;h1&gt;Hello&lt;/h1&gt;"]
  ]

  compileAndRenders.forEach ([tmpl,ctx,toequal]) ->
    it "CompAndRender #{nct.escape(tmpl.replace(/\n/g,' | '))}", ->
      e(nct.renderTemplate(tmpl, ctx)).to.equal toequal

  it "CompAndRender partial", ->
    nct.loadTemplate "{title}", "sub"
    result = nct.renderTemplate "{> sub}", {title: "Hello"}, "t"
    e(result).to.equal "Hello"

  it "CompAndRender programmatic partial", ->
    nct.loadTemplate "{> #subtemplate}", "t"
    nct.loadTemplate "{title}", "sub"
    result = nct.render "t", {title: "Hello", subtemplate: 'sub'}
    e(result).to.equal "Hello"

  it "CompAndRender partial recursive", ->
    context = {name: '1', kids: [{name: '1.1', kids: [{name: '1.1.1', kids: []}] }] }
    nct.loadTemplate "{name}\n{# kids}{> t}{/#}", "t"
    result = nct.render "t", context
    e(result).to.equal "1\n1.1\n1.1.1\n"

  it "Render big list should not be slow", ->
    hours = ({val: i+2, name: "#{i} X"} for i in [1..2000])
    nct.loadTemplate "{# hours }{-val}:{-name}{/#}", "list"
    start = new Date()
    result = nct.render "list", {hours}
    dur = new Date() - start
    e(dur).to.be.below 20