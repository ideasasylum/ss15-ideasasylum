# @codekit-prepend "nav.coffee";
# @codekit-prepend "tabs.coffee";

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
        user = @ref.child("users").child(authData.uid).once('value', (snapshot) =>
          unless snapshot.exists()
            @ref.child("users").child(authData.uid).set(authData);
            token = Math.random().toString(36).substr(2);
            @ref.child("users").child(authData.uid).child('script_token').set(token);
        );
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
    "click button#publish": "publish"

  initialize: () =>
    @rules = new Rules()
    @views = []
    @listenTo @rules, 'sync', @render
    @listenTo @rules, 'add', @render
    @listenTo @rules, 'remove', @render
    @listenTo @rules, 'add', @validate
    @listenTo @rules, 'remove', @validate
    @listenTo @rules, 'sync', @validate

    @fetch_script_token()

  fetch_script_token: () =>
    ref = new Firebase(FIREBASE_URL)
    authData = ref.getAuth()
    snapshot = ref.child("users").child(authData.uid).child('script_token').once('value', (snapshot) =>
      @token = snapshot.val() if snapshot.exists()
      console.log 'script token set', @token
      @render()
    )

  render: () =>
    @$el.html @template(token: @token)
    @rules.each @renderOne, this

    @$el.find(".accordion-tabs-minimal").each (index) ->
      $(this).children("li").first().children("a").addClass("is-active").next().addClass("is-open").show()

    @$el.find(".accordion-tabs-minimal").on "click", "li > a", (event) ->
      unless $(this).hasClass("is-active")
        event.preventDefault()
        accordionTabs = $(this).closest(".accordion-tabs-minimal")
        accordionTabs.find(".is-open").removeClass("is-open").hide()
        $(this).next().toggleClass("is-open").toggle()
        accordionTabs.find(".is-active").removeClass "is-active"
        $(this).addClass "is-active"
      else
        event.preventDefault()
      return

    this

  renderOne: (rule) =>
    view = new RuleView(rule)
    @views.push view
    view.render()
    @$el.find('#rules table tbody').prepend view.el

  add_rule: (e) =>
    rule_form = new RuleForm(@rules)
    @$el.find('#rules').append(rule_form.render().el)
    e.preventDefault()

  publish: (e) =>
    if @rules.length > 0
      ref.child('published').child(@token).set @rules.toJSON()

    e.preventDefault()

  validate: (e) =>
    if @rules.length > 0
      @$el.find('button#publish').show()
    else
      @$el.find('button#publish').hide()

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
  tagName: 'tr'
  className: 'rule'
  template: _.template( $('#rule-template').html() )
  events:
    "click button.remove-rule": "remove"

  initialize: (rule) ->
    @rule = rule

  render: () =>
    @$el.html @template(@rule.attributes)

  remove: (e) =>
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

