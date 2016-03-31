global.Sequelize = require('parent-require') 'sequelize'

module.exports = (sails) ->
  #Sequelize.cls = require('continuation-local-storage').createNamespace('sails-sequelize-postgresql');

  initialize: (next) ->
    sails.adapters ?= {}
    sails.models ?= {}

    connectionName = sails.config.models.connection

    connection = sails.config.connections[connectionName]
    unless connection?
      throw new Error "Sequelize: Connection #{connectionName} not found in config.connections"

    sails.log.verbose "Sequelize: Using connection '#{connectionName}'"

    connection.options ?= {}
    connection.options.logging = connection.options.logging or sails.log.verbose

    #A function that gets executed everytime Sequelize would log something.
    sails.log.verbose "Sequelize: Migration: #{sails.config.models.migrate}"

    if connection.url
      sequelize = new Sequelize(connection.url, connection.options)
    else
      sequelize = new Sequelize(connection.database, connection.user, connection.password, connection.options)

    global.sequelize = sequelize

    sails.modules.loadModels (err, modelDefs) ->

      if err?
        return next err

      for name, modelDef of modelDefs
        sails.log.verbose "Sequelize: Loading model '#{modelDef.globalId}'"

        model = sequelize.define modelDef.globalId, modelDef.attributes, modelDef.options

#        for key, val of model.rawAttributes
#          console.log "   #{key}: #{JSON.stringify sails.util._.omit val, "Model"}"
        global[modelDef.globalId] = model
        sails.models[modelDef.globalId.toLowerCase()] = model

      for name, modelDef of modelDefs
        if modelDef.defaultScope? and typeof modelDef.defaultScope is 'function'
          sails.log.verbose "Sequelize: Loading default scope for '#{modelDef.globalId}'"
          global[modelDef.globalId].addScope 'defaultScope', modelDef.defaultScope() or {}, override: true
        if modelDef.associations? and typeof modelDef.associations is 'function'
          sails.log.verbose "Sequelize: Loading associations for '#{modelDef.globalId}'"
          modelDef.associations modelDef

      if sails.config.models.migrate is 'safe'
        next()
      else
        sequelize.sync
          force: sails.config.models.migrate is 'drop'
        .then ->
          next()