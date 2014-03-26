fs = null
path = null
PackageUpdater = null

getFs = ->
  fs ?= require 'fs-plus'

NAMESPACE = 'auto-update-packages'
WARMUP_WAIT = 10 * 1000
MINIMUM_AUTO_UPDATE_BLOCK_DURATION_MINUTES = 15
DEFAULT_AUTO_UPDATE_BLOCK_DURATION_MINUTES = 6 * 60

module.exports =
  activate: (state) ->
    atom.workspaceView.command "#{NAMESPACE}:update-now", =>
      @updatePackages(false)

    setTimeout =>
      @enableAutoUpdate()
    , WARMUP_WAIT

  deactivate: ->
    @disableAutoUpdate()
    atom.workspaceView.off "#{NAMESPACE}:update-now"

  enableAutoUpdate: ->
    @updatePackagesIfAutoUpdateBlockIsExpired()

    @autoUpdateCheck = setInterval =>
      @updatePackagesIfAutoUpdateBlockIsExpired()
    , @getAutoUpdateCheckInterval()

  disableAutoUpdate: ->
    clearInterval(@autoUpdateCheck) if @autoUpdateCheck
    @autoUpdateCheck = null

  updatePackagesIfAutoUpdateBlockIsExpired: ->
    lastUpdateTime = @loadLastUpdateTime() || 0
    if Date.now() > lastUpdateTime + @getAutoUpdateBlockDuration()
      @updatePackages()

  updatePackages: (isAutoUpdate = true) ->
    PackageUpdater ?= require './package-updater'
    PackageUpdater.updatePackages(isAutoUpdate)
    @saveLastUpdateTime()

  getAutoUpdateBlockDuration: ->
    defaultMinutes = DEFAULT_AUTO_UPDATE_BLOCK_DURATION_MINUTES
    minutes = atom.config.getPositiveInt("#{NAMESPACE}.intervalMinutes", defaultMinutes)

    if minutes < MINIMUM_AUTO_UPDATE_BLOCK_DURATION_MINUTES
      minutes = MINIMUM_AUTO_UPDATE_BLOCK_DURATION_MINUTES

    minutes * 60 * 1000

  getAutoUpdateCheckInterval: ->
    @getAutoUpdateBlockDuration() / 15

  # auto-upgrade-packages runs on each Atom instance,
  # so we need to share the last updated time via a file between the instances.
  loadLastUpdateTime: ->
    try
      string = getFs().readFileSync(@getLastUpdateTimeFilePath())
      parseInt(string)
    catch
      null

  saveLastUpdateTime: ->
    getFs().writeFileSync(@getLastUpdateTimeFilePath(), Date.now().toString())

  getLastUpdateTimeFilePath: ->
    path ?= require 'path'
    dotAtomPath = getFs().absolute('~/.atom')
    path.join(dotAtomPath, 'storage', "#{NAMESPACE}-last-update-time")
