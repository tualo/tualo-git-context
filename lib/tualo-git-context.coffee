TualoGitContextView = require './tualo-git-context-view'
{CompositeDisposable} = require 'atom'
{TextEditor} = require 'atom'

{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

module.exports =
  configDefaults:
    enableAutoActivation: true
    autoActivationDelay: 1000

  tualoGitContextView: null

  activate: (state) ->
    @tualoGitContextView = new TualoGitContextView(state.tualoGitContextViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @tualoGitContextView.getMessageElement(), visible: false)

    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:ignore", => @ignore()
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:staging", => @staging()
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:reset", => @reset()
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:status", => @status()
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:commit", => @commit()


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @tualoGitContextView.destroy()

  serialize: ->
    tualoGitContextViewState: @tualoGitContextView.serialize()



  hideMessage: () ->
      @modalPanel.hide()

  showMessage: (message) ->
    @tualoGitContextView.getMessage().innerHTML = message;
    @modalPanel.show()
    if typeof @messageTimer != 'undefined'
      clearTimeout @messageTimer
    @messageTimer = setTimeout(@hideMessage.bind(@), 3000)



  getCurrentFile: ->
    filePath = @getCurrentTreeItemPath()
    if fs.lstatSync(filePath).isDirectory()
      null
    else
      filePath

  getCurrentPath: ->
    filePath = @getCurrentTreeItemPath()
    if fs.lstatSync(filePath).isDirectory()
      filePath
    else
      null


  getCurrentTreeItemPath: ->
    elem = atom.contextMenu.activeElement.querySelector('span[data-path]')
    if elem==null
      atom.contextMenu.activeElement.getAttribute('data-path')
    else
      elem.getAttribute('data-path')



  gitAdd: (fileName) ->
    options =
      cwd: atom.project.getRepo().getWorkingDirectory()
      timeout: 30000
    shortFilePath = fileName.substring atom.project.getRepo().getWorkingDirectory().length+1
    exec 'git add '+shortFilePath,options, (err,stdout,stderr) =>
      if err
        @showMessage '<pre>'+'ERROR '+err+'</pre>'
      else if stderr
        @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>'
      else
        @showMessage '<pre>'+'file added to stage'+"\n"+'</pre>'
      @tualoGitContextView.gitStatus path,fileName
      @tualoGitContextView.refreshTree()
  staging: ->
    @showMessage 'staging ...'
    fileName = @getCurrentFile()
    if fileName!=null
      if typeof @tualoGitContextView.statusChanged[fileName] == 'object'
        @showMessage 'staging changed file ...'
        @gitAdd fileName

      else if typeof @tualoGitContextView.statusNew[fileName] == 'object'
        @showMessage 'staging new file ...'
        @gitAdd fileName

      else if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
        @showMessage 'this file is allready staged ...'
      else
        @showMessage 'there is nothing to stage ...'
    else
      @showMessage 'only files are supported'



  gitIgnore: (fileName) ->
    options =
      cwd: atom.project.getRepo().getWorkingDirectory()
      timeout: 30000
    shortFilePath = fileName.substring atom.project.getRepo().getWorkingDirectory().length
    #@showMessage atom.project.getRepo().getWorkingDirectory()+"\n"+fileName+"\n"+shortFilePath
    exec 'echo "'+shortFilePath+'" >> .gitignore',options, (err,stdout,stderr) =>
      @showMessage 'added to ignored files'
      @tualoGitContextView.refreshTree()

  ignore: ->
    @showMessage 'ignoring ...'
    fileName = @getCurrentFile()
    if fileName!=null
      if typeof @tualoGitContextView.statusNew[fileName] == 'object'
        @gitIgnore fileName
      else
        @showMessage 'can\'t be ignored ...'
    else
      @showMessage 'only files are supported'





  gitReset: (fileName)->
    options =
      cwd: atom.project.getRepo().getWorkingDirectory()
      timeout: 30000
    shortFilePath = fileName.substring atom.project.getRepo().getWorkingDirectory().length

    exec 'git reset HEAD '+shortFilePath+'',options, (err,stdout,stderr) =>
      @showMessage 'reset to HEAD'
      @tualoGitContextView.refreshTree()
  reset: ->
    @showMessage 'resetting ...'
    fileName = @getCurrentFile()
    if fileName!=null
      if typeof @tualoGitContextView.statusChanged[fileName] == 'object'
        @gitReset fileName
      else if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
        @gitReset fileName
      else
        @showMessage 'can\'t be resetted ...'
    else
      @showMessage 'only files are supported'


  gitStatus: (fileOrPath) ->
    options =
      cwd: atom.project.getRepo().getWorkingDirectory()
      timeout: 30000
    shortFilePath = fileOrPath.substring atom.project.getRepo().getWorkingDirectory().length+1
    exec 'git status '+shortFilePath,options, (err,stdout,stderr) =>
      atom.confirm
        message: 'GIT Status'
        detailedMessage: stdout
        buttons: ['OK']
  status: ->
    @showMessage 'retrieving status ...'
    fileName = @getCurrentFile()
    pathName = @getCurrentPath()
    if fileName!=null
      @gitStatus fileName
    else if pathName!=null
      @gitStatus pathName
    else
      @showMessage 'only files or paths are supported'




  gitCommit: (fileName)->
    options =
      cwd: atom.project.getRepo().getWorkingDirectory()
      timeout: 30000
    shortFilePath = fileName.substring atom.project.getRepo().getWorkingDirectory().length+1
    @tualoGitContextView.setCommitCallback null
    exec 'git commit '+shortFilePath+' -F '+@tualoGitContextView.getCommitFilePath(),options, (err,stdout,stderr) =>
      if err
        @showMessage '<pre>'+'ERROR '+err+'</pre>'
      else if stderr
        @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>'
      else
        @showMessage '<pre>'+'commited'+"\n"+'</pre>'
      fs.unlink @tualoGitContextView.getCommitFilePath()
      @tualoGitContextView.refreshTree()

  commit: ->
    #@showMessage 'commiting ...'
    fileName = @getCurrentFile()
    if fileName!=null
      if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
        atom.workspace.open @tualoGitContextView.getCommitFilePath()
        ctx = @tualoGitContextView
        me = @
        @tualoGitContextView.setCommitCallback () ->
          me.gitCommit fileName
      else
        @showMessage 'there is nothing on stage ...'
    else
      @showMessage 'only files are supported'
