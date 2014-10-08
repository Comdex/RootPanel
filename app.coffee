connect = require 'connect'
nodemailer = require 'nodemailer'
path = require 'path'
harp = require 'harp'
fs = require 'fs'
moment = require 'moment-timezone'
redis = require 'redis'
express = require 'express'
{MongoClient} = require 'mongodb'

global.app = express()

config = null

exports.checkEnvironment = ->
  config_file_path = path.join __dirname, 'config.coffee'

  unless fs.existsSync config_file_path
    default_config_file_path = path.join __dirname, './sample/rpvhost.config.coffee'
    fs.writeFileSync config_file_path, fs.readFileSync default_config_file_path
    console.log '[Warning] Copy sample config file to ./config.coffee'

  fs.chmodSync config_file_path, 0o750

  config = require './config'

  if fs.existsSync config.web.listen
    fs.unlinkSync config.web.listen

exports.run = ->
  exports.checkEnvironment()

  {user, password, host, name} = config.mongodb

  if user and password
    mongodb_uri = "mongodb://#{user}:#{password}@#{host}/#{name}"
  else
    mongodb_uri = "mongodb://#{host}/#{name}"

  MongoClient.connect mongodb_uri, (err, db) ->
    throw err if err
    app.db = db

    app.redis = redis.createClient 6379, '127.0.0.1',
      auth_pass: config.redis_password

    app.mailer = nodemailer.createTransport config.email.account

    app.models =
      mAccount: require './core/model/account'
      mBalanceLog: require './core/model/balance_log'
      mCouponCode: require './core/model/coupon_code'
      mNotification: require './core/model/notification'
      mSecurityLog: require './core/model/security_log'
      mTicket: require './core/model/ticket'

    app.i18n = require './core/i18n'
    app.utils = require './core/utils'
    app.cache = require './core/cache'
    app.config = require './config'
    app.package = require './package.json'
    app.billing = require './core/billing'
    app.pluggable = require './core/pluggable'
    app.middleware = require './core/middleware'
    app.notification = require './core/notification'
    app.authenticator = require './core/authenticator'

    app.template_data =
      ticket_create_email: fs.readFileSync('./core/template/ticket_create_email.html').toString()
      ticket_reply_email: fs.readFileSync('./core/template/ticket_reply_email.html').toString()

    app.use connect.json()
    app.use connect.urlencoded()
    app.use connect.logger()
    app.use require('cookie-parser')()

    app.use require 'middleware-injector'

    app.use (req, res, next) ->
      req.res = res

      res.language = req.cookies.language ? config.i18n.default_language
      res.timezone = req.cookies.timezone ? config.i18n.default_timezone

      res.locals =
        config: config
        app: app
        req: req
        res: res

        t: app.i18n.getTranslator req

        selectHook: (name) ->
          return app.pluggable.selectHook req.account, name

        moment: ->
          return moment.apply(@, arguments).locale(res.language).tz(res.timezone)

      res.t = res.locals.t
      res.moment = res.locals.moment

      res.locals.config.web.name = res.t app.config.web.t_name

      next()

    app.set 'views', path.join(__dirname, 'core/view')
    app.set 'view engine', 'jade'

    app.get '/locale/:language?', app.i18n.downloadLocales

    app.use '/account', require './core/router/account'
    app.use '/billing', require './core/router/billing'
    app.use '/ticket', require './core/router/ticket'
    app.use '/admin', require './core/router/admin'
    app.use '/panel', require './core/router/panel'

    app.pluggable.initializePlugins()

    app.get '/', (req, res) ->
      res.redirect '/panel/'

    app.use harp.mount './core/static'

    app.billing.run()

    app.listen config.web.listen, ->
      fs.chmodSync config.web.listen, 0o770
      console.log "RootPanel start at #{config.web.listen}"

unless module.parent
  exports.run()
