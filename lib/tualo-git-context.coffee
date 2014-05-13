TualoGitContextView = require './tualo-git-context-view'

module.exports =
  tualoGitContextView: null

  activate: (state) ->
    @tualoGitContextView = new TualoGitContextView(state.tualoGitContextViewState)

  deactivate: ->
    @tualoGitContextView.destroy()

  serialize: ->
    tualoGitContextViewState: @tualoGitContextView.serialize()
