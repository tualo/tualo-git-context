TualoGitContextView = require './tualo-git-context-view'

module.exports =
  configDefaults:
    enableAutoActivation: true
    autoActivationDelay: 1000

  tualoGitContextView: null

  activate: (state) ->
    @tualoGitContextView = new TualoGitContextView(state.tualoGitContextViewState)

  deactivate: ->
    @tualoGitContextView.destroy()

  serialize: ->
    tualoGitContextViewState: @tualoGitContextView.serialize()
