# @codekit-prepend "nav.coffee";

FIREBASE_URL = "https://resplendent-torch-5273.firebaseio.com"

class RedirectYourTrafficRouter extends Backbone.Router

  routes:
    "":        "app"
    "signin":  "signin"
    "signout": "signout"
    "rules":   "rules"
    "search/:query/p:page": "search"
    ".*":       "app"

  app: () =>
    console.log "hi"
    @swap_view new AppView()

  signin: () =>
    if @authenticated()
      @navigate 'rules', {trigger: true}
    else
      @ref.authWithOAuthPopup "google", @auth_callback
      # @ref.authWithOAuthRedirect "google", @auth_callback

  signout: () =>
    @enforce_authentication()
    @ref.unauth()
    @auth = null
    console.log 'signed out'
    @navigate '#', {trigger: true}

  rules: () ->
    if @enforce_authentication()
      console.log 'ruled!'
      @swap_view new RulesView()

  enforce_authentication: () =>
    @navigate '', {trigger: true} unless @authenticated()
    @authenticated()

  authenticated: () =>
    unless @ref
      @ref = new Firebase(FIREBASE_URL)
    @auth = @ref.getAuth() unless @auth
    console.log 'authed as', @auth
    @auth

  swap_view: (view) =>
    @view?.destroy
    @view = view
    @view.render()

  auth_callback: (error, authData) =>
    if error
      console.log "Login Failed!", error
      # fall-back to browser redirects, and pick up the session
      # automatically when we come back to the origin page
      if error.code == "TRANSPORT_UNAVAILABLE"
        @ref.authWithOAuthRedirect "google", @auth_callback
      @navigate ''
    else
      console.log "Authenticated successfully with payload:", authData
      # save the user's profile into Firebase so we can list users,
      # use them in Security and Firebase Rules, and show profiles
      if authData
        user = @ref.child("users").child(authData.uid)
        unless user
          @ref.child("users").child(authData.uid).set(authData);
      @navigate 'rules', { trigger: true }


class AppView extends Backbone.View
  el: '#app'
  template: _.template( $('#app-template').html() )

  render: () =>
    @$el.html @template()
    this

class RulesView extends Backbone.View
  el: '#app'
  template: _.template( $('#rules-template').html() )

  events:
    "click button#addrule": "add_rule"

  initialize: () =>
    @rules = new Rules()
    @views = []
    @listenTo @rules, 'sync', @render
    @listenTo @rules, 'add', @render
    @listenTo @rules, 'remove', @render

  render: () =>
    @$el.html @template()
    @rules.each @renderOne, this
    this

  renderOne: (rule) =>
    view = new RuleView(rule)
    @views.push view
    view.render()
    @$el.append view.el

  add_rule: (e) =>
    rule_form = new RuleForm(@rules)
    @$el.append(rule_form.render().el)
    e.preventDefault()

class RuleForm extends Backbone.View
  tag: 'div'
  className: 'rule-form'
  template: _.template( $('#rule-form-template').html() )
  events:
    "click button#save-rule": "save"
    "keyup input": "update"

  initialize: (rules) ->
    @rule = new Rule()
    @rules = rules

  render: () =>
    @$el.html @template(@rule.attributes)
    this

  update: (e) =>
    input = $(e.currentTarget)
    @rule.set input.attr('name'), input.val()

  save: (e) ->
    @rules.add @rule.attributes
    e.preventDefault()

class RuleView extends Backbone.View
  tag: 'div'
  className: 'rule'
  template: _.template( $('#rule-template').html() )
  events:
    "click button.remove-rule": "remove"

  initialize: (rule) ->
    @rule = rule

  render: () =>
    @$el.html @template(@rule.attributes)

  remove: (e) =>
    debugger
    e.preventDefault()
    @rule.destroy()


class Rule extends Backbone.Model
  defaults:
    subject: 'referrer'
    referrer: ''
    dest: ''

class Rules extends Backbone.Firebase.Collection
  url: () ->
    user = new Firebase(FIREBASE_URL).getAuth()
    uid = user.uid if user
    "#{FIREBASE_URL}/rules/#{uid}/" if uid
  autoSync: true
  model: Rule

app = app || {}
app.Router = new RedirectYourTrafficRouter()
Backbone.history.start()

