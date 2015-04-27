{WorkspaceView} = require 'atom'
TualoGitContext = require '../lib/tualo-git-context'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

#describe "TualoGitContext", ->
#  it "working dir", ->
#    expect(atom.project.getRepo().getWorkingDirectory()).toExist()

#  activationPromise = null
#
#  beforeEach ->
#    atom.workspaceView = new WorkspaceView
#    activationPromise = atom.packages.activatePackage('tualo-git-context')
#
#  describe "when the tualo-git-context:toggle event is triggered", ->
#    it "attaches and then detaches the view", ->
#      expect(atom.workspaceView.find('.tualo-git-context')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
#      atom.workspaceView.trigger 'tualo-git-context:toggle'

#      waitsForPromise ->
#        activationPromise

#      runs ->
#        expect(atom.workspaceView.find('.tualo-git-context')).toExist()
#        atom.workspaceView.trigger 'tualo-git-context:toggle'
#        expect(atom.workspaceView.find('.tualo-git-context')).not.toExist()
