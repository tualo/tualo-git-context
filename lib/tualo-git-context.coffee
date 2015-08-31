TualoGitContextView = require './tualo-git-context-view'
{CompositeDisposable} = require 'atom'
{TextEditor} = require 'atom'

{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'


module.exports =
  #configDefaults:
  #  enableAutoActivation: true
  #  autoActivationDelay: 1000

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
    @subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:checkouthead", => @checkouthead()

    @branchCMDS = {}



    status =
        label: 'Status',
        command:'tualo-git-context:status',
        shouldDisplay: (event)->
          false
    me = @


    atom.contextMenu.add {
      '.tree-view': [{
        label: 'Git',
        #command:'tualo-git-context:dummy',
        shouldDisplay: (event)->
          if me.gitSubMenu==null
            false

          if typeof me.treeView == 'undefined'
            me.treeView = me.getTreeView()
          pathName = event.target.dataset.path
          if pathName
          else
            elem = event.target.querySelector('span[data-path]')
            if elem?
              pathName = elem.getAttribute('data-path')


          if pathName
            if (me.getRepository())
              shortFilePath = pathName.substring me.getRepository().getWorkingDirectory().length+1

              me.gitSubMenu.submenu = [];
              branches = me.tualoGitContextView.branches

              for name of branches
                if typeof me.branchCMDS[name]=='undefined'
                  me.branchCMDS[name]=true
                  n = name+""
                  me.subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:checkout-"+n, me.checkoutCMD(n)
                  me.subscriptions.add atom.commands.add "atom-workspace","tualo-git-context:pushorigin-"+n, me.pushoriginCMD(n)


              currentbranch = null
              (currentbranch = name for name of branches when branches[name].current == true)

              if typeof me.tualoGitContextView.statusNew[pathName] == 'object' or
                 typeof me.tualoGitContextView.statusChanged[pathName] == 'object' or
                 fs.lstatSync(pathName).isDirectory()
                me.gitSubMenu.submenu.push {label: 'Stage', command:'tualo-git-context:staging'}

              if typeof me.tualoGitContextView.statusStaged[pathName] == 'object' or
                 fs.lstatSync(pathName).isDirectory()
                me.gitSubMenu.submenu.push {label: 'Commit', command:'tualo-git-context:commit'}

              me.gitSubMenu.submenu.push {label: '-',type: 'separator'}
              me.gitSubMenu.submenu.push {label: 'Status *'+currentbranch+'*', command:'tualo-git-context:status'}
              me.gitSubMenu.submenu.push {label: '-',type: 'separator'}
              me.gitSubMenu.submenu.push {label: 'Ignore', command:'tualo-git-context:ignore'}
              me.gitSubMenu.submenu.push {label: '-',type: 'separator'}


              me.gitSubMenu.submenu.push {label: 'Remove', command:'tualo-git-context:remove'}

              if typeof me.tualoGitContextView.statusStaged[pathName] == 'object'
                me.gitSubMenu.submenu.push {label: 'Reset (single file)', command:'tualo-git-context:reset'}

              if typeof me.tualoGitContextView.statusNew[pathName] == 'undefined'
                me.gitSubMenu.submenu.push {label: 'Checkout HEAD', command:'tualo-git-context:checkouthead'}

              branchessubmenu = []
              ( branchessubmenu.push({label: 'Checkout '+name, command:'tualo-git-context:checkout-'+name }) for name of branches when branches[name].current != true)
              me.gitSubMenu.submenu.push {label: 'Checkout', submenu: branchessubmenu}

              me.gitSubMenu.submenu.push {label: 'Revert (all files)', command:'tualo-git-context:revert'}
              me.gitSubMenu.submenu.push {label: '-',type: 'separator'}

              if me.tualoGitContextView.remote!=""
                me.gitSubMenu.submenu.push {label: 'Push '+me.tualoGitContextView.remote+' '+currentbranch, command:'tualo-git-context:pushorigin-'+currentbranch}

              true
            else
              false
          else
            false

        submenu: [
          {label: 'Stage (single file)', command:'tualo-git-context:staging'},
          {label: 'Commit', command:'tualo-git-context:commit'},
          {label: 'Status', command:'tualo-git-context:status'},
          {label: 'Remove', command:'tualo-git-context:remove'}
          {label: 'Reset (single file)', command:'tualo-git-context:reset'}
          {label: 'Revert (all files)', command:'tualo-git-context:revert'}
          {label: 'Checkout HEAD', command:'tualo-git-context:checkouthead'}
          {label: 'Ignore', command:'tualo-git-context:ignore'}
        ]
      }]
    }

    @gitSubMenu = null
    for item in atom.contextMenu.itemSets
      #if item.items[0].command == 'tualo-git-context:dummy'
      if item.items[0].label == 'Git'
        @gitSubMenu = item.items[0] #item.items[0].submenu
    # ContextMenuManager

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @tualoGitContextView.destroy()

  serialize: ->
    tualoGitContextViewState: @tualoGitContextView.serialize()


  getTreeView: ->
    result = null
    panels = atom.workspace.getLeftPanels()
    panels = panels.concat atom.workspace.getTopPanels()
    panels = panels.concat atom.workspace.getRightPanels()
    panels = panels.concat atom.workspace.getBottomPanels()

    (result = item.item for item in panels when typeof item.item.getSelectedEntries == 'function' and typeof item.item.getActivePath == 'function' )
    result

    #console.log panels[0].querySelector('div.tree-view-resizer.tool-panel')
    #atom.workspace.getLeftPanels()[0].item.getSelectedEntries()
    #div.tree-view-resizer.tool-panel
    #  getCurrentTreeItemPath: ->
    #    elem = atom.contextMenu.activeElement.querySelector('span[data-path]')



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

  getShortNames: (entries) ->
    result = []
    wd_length = @getRepository().getWorkingDirectory().length+1
    for item in entries
      name = ""
      if typeof item.file == 'object'
        name = item.file.path
      if typeof item.directory == 'object'
        name = item.directory.path
      if name != ""
        name = name.substring wd_length
        if name == ""
            name = "."
        result.push name
    result


  gitAdd: (entries) ->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      me = @
      exec 'git add '+entries.join(' '),options, (err,stdout,stderr) =>
        if err
          me.showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          me.showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          me.showMessage '<pre>'+'file added to stage'+"\n"+'</pre>', 1000
        (me.tualoGitContextView.gitStatus(entry) for entry in entries)
  staging: ->
    if @getRepository()
      entries = @getShortNames @treeView.getSelectedEntries()
      @gitAdd entries


  gitIgnore: (fileName) ->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      me = @
      exec 'echo "'+shortFilePath+'" >> .gitignore',options, (err,stdout,stderr) =>
        if err
          me.showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
        else if stderr
          me.showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
        else
          me.showMessage '<pre>'+'added to .gitignore'+"\n"+'</pre>', 1000
        me.tualoGitContextView.gitStatus shortFilePath

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
        maxBuffer: 1048576
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


  gitStatus: (shortEntries) ->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      exec 'git status '+shortEntries.join(' '),options, (err,stdout,stderr) =>
        atom.confirm
          message: 'GIT Status'
          detailedMessage: stdout
          buttons: ['OK']
  status: ->
    if @getRepository()
      entries = @getShortNames @treeView.getSelectedEntries()
      @gitStatus entries




  gitCommit: (entries)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      #shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      #if shortFilePath == ''
      #  shortFilePath = '.'

      @tualoGitContextView.setCommitCallback null
      me = @
      msgdata = fs.readFileSync me.tualoGitContextView.getCommitFilePath()
      msg = []
      lines = msgdata.toString().split("\n")
      (msg.push(line) for line in lines when line.substring(0,1) != '#' )
      fs.writeFileSync me.tualoGitContextView.getCommitFilePath(),msg.join("\n")
      cmt = ()  ->
        exec 'git commit '+entries.join(' ')+' -F '+me.tualoGitContextView.getCommitFilePath(),options, (err,stdout,stderr) =>
          if err
            me.showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
          else if stderr
            me.showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
          else
            me.showMessage '<pre>'+'commited'+"\n"+'</pre>', 1000
          fs.unlink me.tualoGitContextView.getCommitFilePath()
          (me.tualoGitContextView.gitStatus(entry) for entry in entries)
      setTimeout cmt,500 # fixing .git/index.lock error

  commit: ->
    if @getRepository()
      entries = @getShortNames @treeView.getSelectedEntries()
      me = @
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      cmd = 'status'
      if entries.length == 1 and not fs.lstatSync( path.join( @getRepository().getWorkingDirectory(),entries[0]) ).isDirectory()
        cmd = 'diff --cached'
      exec 'git '+cmd+' '+entries.join(' '),options, (err,stdout,stderr) =>
        lines = "\n#"+stdout.split("\n").join("\n#")
        fs.writeFileSync me.tualoGitContextView.getCommitFilePath(),lines
        atom.workspace.open me.tualoGitContextView.getCommitFilePath()
        ctx = me.tualoGitContextView
        me.tualoGitContextView.setCommitCallback () ->
          me.gitCommit entries



  gitRemove: (fileName,type)->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
      shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1
      opt = ''
      if type == 'path'
        opt = '-r'
      exec 'git rm '+opt+' --cached '+shortFilePath+'',options, (err,stdout,stderr) =>
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
      type = 'file';
      fileName = @getCurrentFile()
      if not fileName?
        fileName = @getCurrentPath()
        type = 'path'
      atom.confirm
          message: "Removing the "+type+" "+fileName+". Are you sure?"
          buttons:
            Cancel: =>

            Remove: =>
              if fileName?
                if typeof @tualoGitContextView.statusChanged[fileName] == 'object'
                  @gitRemove fileName, type
                else if typeof @tualoGitContextView.statusStaged[fileName] == 'object'
                  @gitRemove fileName, type
                else if typeof @tualoGitContextView.statusClean[fileName] == 'object'
                  @gitRemove fileName, type
                else
                  @gitRemove fileName, type
              else
                @showMessage 'only files are supported'






  gitRevert: ()->
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
        maxBuffer: 1048576
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
          message: "All not commited changes will be lost. Are you sure?"
          buttons:
            Cancel: =>

            Revert: =>
              @gitRevert()



  gitCheckouthead: (fileName)->
    if fileName?
      if @getRepository()
        options =
          cwd: @getRepository().getWorkingDirectory()
          timeout: 30000
          maxBuffer: 1048576
        shortFilePath = fileName.substring @getRepository().getWorkingDirectory().length+1

        if shortFilePath == ''
          shortFilePath = '.'

        exec 'git checkout HEAD '+shortFilePath+'',options, (err,stdout,stderr) =>
          @showMessage 'reset to HEAD'
          if err
            @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
          else if stderr
            @showMessage '<pre>'+'ERROR '+stderr+" "+stdout+'</pre>', 5000
          else
            @showMessage '<pre>'+'checked out'+"\n"+'</pre>', 1000
          @tualoGitContextView.gitStatus shortFilePath


  checkouthead: ->
    if @getRepository()
      type = 'file';
      fileName = @getCurrentFile()
      if not fileName?
        fileName = @getCurrentPath()
        type = 'path'
      atom.confirm
          message: "All not commited changes on this "+type+" will be lost. Are you sure?"
          buttons:
            Cancel: =>

            Checkout: =>
              @gitCheckouthead fileName


  gitPush: (name)->
    if name?
      if @getRepository()
        options =
          cwd: @getRepository().getWorkingDirectory()
          timeout: 30000
          maxBuffer: 1048576
        exec 'git push '+@tualoGitContextView.remote+' '+name,options, (err,stdout,stderr) =>
          if err
            @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
          else
            @showMessage '<pre>'+''+stderr+" "+stdout+'</pre>', 5000


  pushoriginCMD: (name)->
    me = @

    () ->
      me.pushorigin name
  pushorigin: (name)->
    me = @
    if @getRepository()
      atom.confirm
          message: "Push branch "+name+" to "+me.tualoGitContextView.remote+". Are you sure?"
          buttons:
            Cancel: =>

            Push: =>
              me.gitPush name

  gitCheckout: (name)->
    if name?
      if @getRepository()
        options =
          cwd: @getRepository().getWorkingDirectory()
          timeout: 30000
          maxBuffer: 1048576
        exec 'git checkout '+name,options, (err,stdout,stderr) =>
          if err
            @showMessage '<pre>'+'ERROR '+err+'</pre>', 5000
          else
            @showMessage '<pre>'+''+stderr+" "+stdout+'</pre>', 5000

          @tualoGitContextView.getBranches()

  checkoutCMD: (name)->
    me = @
    () ->
      me.checkout name
  checkout: (name)->
    if @getRepository()

      @gitCheckout name
