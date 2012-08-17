
coffee = require '../lib/coffee'
e = require('chai').expect
nct = require '../lib/nct'

cc = (fn, ctx={}) ->
  tmpl = coffee.compile(fn)
  fn = nct.loadTemplate(tmpl)
  fn(new nct.Context(ctx))


describe "Test Coffeescript Precompiler", ->
  it "should output a div as a string from string", ->
    e(cc("div('hello')")).to.equal '<div>hello</div>'

  it "should output a div as a string from function", ->
    e(cc(-> div 'hello')).to.equal '<div>hello</div>'

  it "should compile to nct template", ->
    e(cc((-> div -> ctx('msg')), {msg: 'hi'})).to.equal '<div>hi</div>'

  it "should output element's id", ->
    e(cc(-> div '#myid', "hello")).to.equal '<div id="myid">hello</div>'

  it "should support classes", ->
    e(cc(-> div '.test', "hi")).to.equal '<div class="test">hi</div>'
    e(cc(-> div '.test.two', "hi")).to.equal '<div class="test two">hi</div>'
  it "should support ids and classes", ->
    e(cc(-> div '#myid.test.two', "hi")).to.equal '<div id="myid" class="test two">hi</div>'

  it "should render attrs provided as object", ->
    e(cc(-> div {name: 'joe'})).to.equal '<div name="joe"></div>'

  it "should render attrs provided as object", ->
    e(cc(-> div {data: {name: 'joe'}})).to.equal '<div data-name="joe"></div>'

  it "should render nested tags", ->
    e(cc(-> div -> span "Hello")).to.equal '<div><span>Hello</span></div>'