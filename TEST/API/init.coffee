async = require 'async'

db = require '../../core/db'

module.exports = (callback) ->
  cAccount = db.collection 'accounts'
  cTicket = db.collection 'tickets'

  async.parallel [
    (callback) ->
      cAccount.remove
        username: $in: ['test', 'test_main']
      , callback

    (callback) ->
      cAccount.remove
        email: 'test@jysperm.me'
      , callback

    (callback) ->
      cAccount.insert
        _id: db.ObjectID '533b0cb894f6c673123e33a3'

        username: 'test_main'
        password: 'a75b5ef8038c8bd6f623beaee94fd429e522d6f00f94183c0023655e723cf123'
        password_salt: '891bad13e24d964bc7a95b97b6762926719fec8739d2ca23e6b1089d4ca273a9'
        email: 'test_main@jysperm.me'
        singup_at: new Date()

        group: ['root']
        setting: {}
        attribute: {}

        tokens: [
          {
            token: 'token'
            available: true
            created_at: new Date()
            updated_at: new Date()

            attribute: {}
          },
          {
            token: 'need_be_remove'
            available: true
            created_at: new Date()
            updated_at: new Date()

            attribute: {}
          }
        ]
      , callback

    (callback) ->
      cTicket.remove
        account_id: db.ObjectID '533b0cb894f6c673123e33a3'
      , callback

    (callback) ->
      cTicket.insert
        _id: db.ObjectID '533b0cb894f6c673123e33a4'
        account_id: db.ObjectID '533b0cb894f6c673123e33a3'
        created_at: new Date()
        updated_at: new Date()
        title: 'Ticket Title'
        content: 'Ticket Content(Markdown)'
        content_html: 'Ticket Conetnt(HTML)'
        type: 'linux'
        status: 'open'
        members: [
          db.ObjectID '533b0cb894f6c673123e33a3'
        ]
        attribute: {}
        replys: []
      , callback

  ], ->
    callback()

unless module.parent
  db.connect ->
    module.exports ->
      process.exit()
