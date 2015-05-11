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
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:remove", => @remove()
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:revert", => @revert()

    console.log 'ok*'
    status =
        label: 'Status',
        command:'tualo-git-context:status',
        shouldDisplay: (event)->
          console.log('---',event)
          false
    me = @


    atom.contextMenu.add {
      '.tree-view': [{
        label: 'Git',
        shouldDisplay: (event)->
          pathName = event.target.dataset.path
          if pathName
          else
            elem = event.target.querySelector('span[data-path]')
            pathName = elem.getAttribute('data-path')

          if pathName
            shortFilePath = pathName.substring me.getRepository().getWorkingDirectory().length+1

            me.gitSubMenu.submenu = [];

            if typeof me.tualoGitContextView.statusNew[pathName] == 'object' or
               typeof me.tualoGitContextView.statusChanged[pathName] == 'object'
              me.gitSubMenu.submenu.push {label: 'Stage (single file)', command:'tualo-git-context:staging'}

            if typeof me.tualoGitContextView.statusStaged[pathName] == 'object'
              me.gitSubMenu.submenu.push {label: 'Commit (single file)', command:'tualo-git-context:commit'}

            me.gitSubMenu.submenu.push {label: '-',type: 'separator'}
            me.gitSubMenu.submenu.push {label: 'Status (single file)', command:'tualo-git-context:status'}
            me.gitSubMenu.submenu.push {label: '-',type: 'separator'}
            me.gitSubMenu.submenu.push {label: 'Ignore (single file)', command:'tualo-git-context:ignore'}
            me.gitSubMenu.submenu.push {label: '-',type: 'separator'}

            #if typeof me.tualoGitContextView.statusNew[pathName] == 'undefined'
            #  me.gitSubMenu.submenu.push {label: 'Checkout HEAD (single file)', command:'tualo-git-context:checkout'}

            me.gitSubMenu.submenu.push {label: 'Remove (single file)', command:'tualo-git-context:remove'}

            if typeof me.tualoGitContextView.statusStaged[pathName] == 'object'
              me.gitSubMenu.submenu.push {label: 'Reset (single file)', command:'tualo-git-context:reset'}

            me.gitSubMenu.submenu.push {label: 'Revert (all files)', command:'tualo-git-context:revert'}
            true
          else
            false
        submenu: [
          {label: 'Stage (single file)', command:'tualo-git-context:staging'},
          {label: 'Commit (single file)', command:'tualo-git-context:commit'},
          {label: 'Status (single file)', command:'tualo-git-context:status'},
          {label: 'Remove (single file)', command:'tualo-git-context:remove'}
          {label: 'Reset (single file)', command:'tualo-git-context:reset'}
          {label: 'Revert (all files)', command:'tualo-git-context:revert'}
          {label: 'Ignore (single file)', command:'tualo-git-context:ignore'}
        ]
      }]
    }


    @gitSubMenu = null
    for item in atom.contextMenu.itemSets
      if item.items[0].label=='Git'
        console.log item.items[0].submenu
        @gitSubMenu = item.items[0] #item.items[0].submenu
    # ContextMenuManager

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @tualoGitContextView.destroy()

  serialize: ->
    tualoGitContextViewState: @tualoGitContextView.serialize()



  hideMessage: () ->
      @modalPanel.hide()

  showMessage: (message,timeout) ->
    if typeof timeout == 'undefined'
      timeout = 3000
    @tualoGitContextView.getMessage().innerHTML = message;
    @modalPanel.show()
    if typeof @messageTimer != 'undefined'
      clearTimeout @messageTimer
    @messageTimer = setTimeout(@hideMessage.bind(@), timeout)



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

  getRepository: ->
    repos = atom.project.getRepositories()
    if repos.length>0
      return repos[0]


  gitAdd: (fileName) ->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      exec 'git add '+shortFilePath,options, (err,stdout,stderr) =>

        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'file added to stage'+"\n"+'</pre>', 1000
        @tualoGitContextView.gitStatus shortFilePath
  staging: ->
    if @getRepository()
      @showMessage 'staging ...'
      fileName = @getCurrentFile()
      if fileName!=null
        if typeof @tualoGitContextView.statusChanged[fileName] == 'object'
          @showMessage 'staging changed file ...', 1000
          @gitAdd fileName

        else if typeof @tualoGitContextView.statusNew[fileName] == 'object'
          @showMessage 'staging new file ...', 1000
          @gitAdd fileName

        else if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
          @showMessage 'this file is allready staged ...', 3000
        else
          @showMessage 'there is nothing to stage ...', 3000
      else
        @showMessage 'only files are supported', 3000



  gitIgnore: (fileName) ->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length-1
      exec 'echo "'+shortFilePath+'" >> .gitignore',options, (err,stdout,stderr) =>
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'added to .gitignore'+"\n"+'</pre>', 1000
        @tualoGitContextView.getStatus  @getRepository().getWorkingDirectory(),shortFilePath

  ignore: ->
    if @getRepository()
      @showMessage 'ignoring ...'
      fileName = @getCurrentFile()
      if fileName!=null
        if typeof @tualoGitContextView.statusNew[fileName] == 'object'
          @gitIgnore fileName
        else
          @showMessage 'can\'t be ignored ...', 5000
      else
        @showMessage 'only files are supported', 5000





  gitReset: (fileName)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1

      exec 'git reset HEAD '+shortFilePath+'',options, (err,stdout,stderr) =>
        @showMessage 'reset to HEAD'
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'file was unstaged'+"\n"+'</pre>', 1000
        @tualoGitContextView.gitStatus shortFilePath

  reset: ->
    if @getRepository()
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
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileOrPath.substring @getRepository().getWorkingDirectory().length+1
      exec 'git status '+shortFilePath,options, (err,stdout,stderr) =>
        atom.confirm
          message: 'GIT Status'
          detailedMessage: stdout
          buttons: ['OK']
  status: ->
    if @getRepository()
      @showMessage 'retrieving status ...',1000
      fileName = @getCurrentFile()
      pathName = @getCurrentPath()
      if fileName!=null
        @gitStatus fileName
      else if pathName!=null
        @gitStatus pathName
      else
        @showMessage 'only files or paths are supported'




  gitCommit: (fileName)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      @tualoGitContextView.setCommitCallback null
      exec 'git commit '+shortFilePath+' -F '+@tualoGitContextView.getCommitFilePath(),options, (err,stdout,stderr) =>
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'commited'+"\n"+'</pre>', 1000
        fs.unlink @tualoGitContextView.getCommitFilePath()
        @tualoGitContextView.gitStatus shortFilePath

  commit: ->
    if @getRepository()
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


  gitCommit: (fileName)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      @tualoGitContextView.setCommitCallback null
      exec 'git commit '+shortFilePath+' -F '+@tualoGitContextView.getCommitFilePath(),options, (err,stdout,stderr) =>
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'commited'+"\n"+'</pre>', 1000
        fs.unlink @tualoGitContextView.getCommitFilePath()
        @tualoGitContextView.gitStatus shortFilePath






  gitRemove: (fileName)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1

      exec 'git rm --cached '+shortFilePath+'',options, (err,stdout,stderr) =>
        @showMessage 'reset to HEAD'
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'file was unstaged'+"\n"+'</pre>', 1000
        @tualoGitContextView.gitStatus shortFilePath

  remove: ->
    if @getRepository()
      @showMessage 'removing ...'
      fileName = @getCurrentFile()
      if fileName!=null
        if typeof @tualoGitContextView.statusChanged[fileName] == 'object'
          @gitRemove fileName
        else if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
          @gitRemove fileName
        else if typeof @tualoGitContextView.statusClean[fileName] == 'object'
          @gitRemove fileName
        else
          @showMessage 'this file isn\'t on your index'
      else
        @showMessage 'only files are supported'






  gitRevert: ()->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      exec 'git revert HEAD',options, (err,stdout,stderr) =>
        @showMessage 'revert to HEAD'
        if err
          @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          @showMessage '<pre>'+'reverted'+"\n"+'</pre>', 1000
        @tualoGitContextView.refreshTree()

  revert: ->
    if @getRepository()
      atom.confirm
          message: "You sure?"
          buttons:
            Cancel: =>

            Revert: =>
              @gitRevert()
