global.Sequelize = require('parent-require') 'sequelize'

module.exports = (sails) ->

  configure: ->
    sails.log.verbose "sequelize: configuring.."

  initialize: (next) ->
    sails.adapters ?= {}
    sails.models ?= {}

    connectionName = sails.config.models.connection

    connection = sails.config.connections[connectionName]
    unless connection?
      throw new Error "sequelize: Connection #{connectionName} not found in config.connections"

    sails.log.verbose "sequelize: Using connection '#{connectionName}'"

    connection.options ?= {}
    #A function that gets executed everytime Sequelize would log something.
    connection.options.logging = connection.options.logging or sails.log.verbose

    if connection.url
      sequelize = new Sequelize(connection.url, connection.options)
    else
      sequelize = new Sequelize(connection.database, connection.user, connection.password, connection.options)

    global.sequelize = sequelize

    sails.modules.loadModels (err, modelDefs) ->

      if err?
        return next err

      for name, modelDef of modelDefs
        sails.log.verbose "sequelize: Loading model '#{modelDef.globalId}'"

        model = sequelize.define modelDef.globalId, modelDef.attributes, modelDef.options

        global[modelDef.globalId] = model
        sails.models[modelDef.globalId.toLowerCase()] = model

      for name, modelDef of modelDefs
        if modelDef.defaultScope? and typeof modelDef.defaultScope is 'function'
          sails.log.verbose "sequelize: Loading default scope for '#{modelDef.globalId}'"
          global[modelDef.globalId].addScope 'defaultScope', modelDef.defaultScope() or {}, override: true
        if modelDef.associations? and typeof modelDef.associations is 'function'
          sails.log.verbose "sequelize: Loading associations for '#{modelDef.globalId}'"
          modelDef.associations modelDef

      if sails.config.models.migrate is 'safe'
        sails.log.verbose "sequelize: not migrating."
        next()
      else
        sails.log.verbose "sequelize: starting migration: #{sails.config.models.migrate}"
        force = sails.config.models.migrate is 'drop'
        sequelize.sync {force}
        .then ->
          sails.log.verbose "sequelize: successfully migrated."
          next()
        .catch (err) ->
          sails.log.error "sequelize: error running migrations: #{err.message}"
          next err
