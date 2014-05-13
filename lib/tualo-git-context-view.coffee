{View} = require 'atom'
{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

module.exports =
class TualoGitContextView extends View
  @content: ->
    @div class: 'tualo-git-context'#, =>
#      @div "The TualoGitContext package is Alive! It's ALIVE!", class: "message"

  initialize: (serializeState) ->
    atom.workspaceView.command "tualo-git-context:toggle", => @toggle()
    atom.workspaceView.command "tualo-git-context:ignore", => @ignore()
    atom.workspaceView.command "tualo-git-context:staging", => @staging()
    atom.workspaceView.command "tualo-git-context:reset", => @reset()
    atom.workspaceView.command "tualo-git-context:status", => @status()
    atom.workspaceView.command "tualo-git-context:commit", => @commit()


  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  commit: ->

    classNames = ""
    filePath = ""
    if (atom.contextMenu.activeElement.tagName == 'SPAN')
      classNames = atom.contextMenu.activeElement.parentElement.className
      filePath = atom.contextMenu.activeElement.getAttribute('data-path')
    else
      classNames = atom.contextMenu.activeElement.className
      filePath = atom.contextMenu.activeElement.childNodes[0].getAttribute('data-path')

    classes = classNames.split(' ');
    if (classes.indexOf('file')>=0)
      if (classes.indexOf('status-staged')>=0)
        fileName = path.join atom.project.getPath(), '.git-commit-message'+crypto.randomBytes(8).toString('hex')
        fs.writeFileSync fileName, ''

        editor = atom.workspaceView.openSync fileName
        editor.on 'destroyed', () =>
          fileBuffer = fs.readFileSync fileName
          if fileBuffer.length > 0
            #console.log 'GIT Commit: call the command here'
            options =
              cwd: atom.project.getPath()
              timeout: 30000
            exec 'git commit -F '+fileName+' ./'+filePath,options, (err,stdout,stderr) =>
              console.log err,stdout,stderr
              @refreshTree()
              @unlinkMessageFile(fileName)
          else
            #console.log 'GIT Commit: nothing to commit'
            @unlinkMessageFile(fileName)

      else
        console.log "Only modified files can be added to the stage!"
    else
      console.log "currently only files are supported"



    #editorView = atom.workspaceView.getActiveView()
    #res = atom.workspaceView.open fileName
    #console.log res
    #atom.workspaceView.one 'core:save',() =>
    #  console.log fileName
  unlinkMessageFile: (fileName)->
    if fs.existsSync(fileName)
      fs.unlink fileName








  staging: ->
    classNames = ""
    filePath = ""
    if (atom.contextMenu.activeElement.tagName == 'SPAN')
      classNames = atom.contextMenu.activeElement.parentElement.className
      filePath = atom.contextMenu.activeElement.getAttribute('data-path')
    else
      classNames = atom.contextMenu.activeElement.className
      filePath = atom.contextMenu.activeElement.childNodes[0].getAttribute('data-path')

    classes = classNames.split(' ');
    if (classes.indexOf('file')>=0)
      if classes.indexOf('status-modified')>=0 || classes.indexOf('status-added')>=0
        options =
          cwd: atom.project.getPath()
          timeout: 30000
        exec 'git add ./'+filePath,options, (err,stdout,stderr) =>
          console.log err,stdout,stderr
          @refreshTree
      else
        console.log "Only modified files can be added to the stage!"
    else
      console.log "currently only files are supported"


  ignore: ->
    classNames = ""
    filePath = ""
    if (atom.contextMenu.activeElement.tagName == 'SPAN')
      classNames = atom.contextMenu.activeElement.parentElement.className
      filePath = atom.contextMenu.activeElement.getAttribute('data-path')
    else
      classNames = atom.contextMenu.activeElement.className
      filePath = atom.contextMenu.activeElement.childNodes[0].getAttribute('data-path')

    classes = classNames.split(' ');
    if (classes.indexOf('file')>=0)
      options =
        cwd: atom.project.getPath()
        timeout: 30000
      exec 'echo "'+filePath+'" >> .gitignore',options, (err,stdout,stderr) =>
        console.log err,stdout,stderr
        @refreshTree
    else
      console.log "currently only files are supported"
      @refreshTree

  status: ->
    options =
      cwd: atom.project.getPath()
      timeout: 30000
    exec 'git status',options, (err,stdout,stderr) =>
      @refreshTree
      atom.confirm
        message: 'GIT Status'
        detailedMessage: stdout
        buttons: ['OK']

  reset: ->
    classNames = ""
    filePath = ""
    if (atom.contextMenu.activeElement.tagName == 'SPAN')
      classNames = atom.contextMenu.activeElement.parentElement.className
      filePath = atom.contextMenu.activeElement.getAttribute('data-path')
    else
      classNames = atom.contextMenu.activeElement.className
      filePath = atom.contextMenu.activeElement.childNodes[0].getAttribute('data-path')

    classes = classNames.split(' ');
    if (classes.indexOf('file')>=0)
      options =
        cwd: atom.project.getPath()
        timeout: 30000
      exec 'git reset HEAD '+filePath+'',options, (err,stdout,stderr) =>
        @refreshTree
        console.log err,stdout,stderr

    else
      @refreshTree
      console.log "currently only files are supported"

    console.log classNames, filePath





  toggle: ->

    if @hasParent()
      clearInterval atom.get('tualo-git-intervalID')
      @detach()
    else
      @refreshTree()
      intervallID = setInterval @refreshTree, 5000
      atom.set('tualo-git-intervalID',intervallID)
      atom.workspaceView.append(this)



  refreshTree: ->
    #console.log atom.get('tualo-git-intervalID')
    root = atom.project.getRootDirectory()
    root.getEntries (error,files) =>

      options =
        cwd: atom.project.getPath()
        timeout: 30000
      exec 'git status',options, (err,stdout,stderr) =>
        lines = stdout.split("\n")
        state = 0
        atom.workspaceView.find('span[data-path]').parent().removeClass('status-staged');

        for i in [0...lines.length]
          p = lines[i].indexOf(":")
          fstate = lines[i].substring(0,p).replace(/\s/g,'')
          fname = lines[i].substring(p+1).replace(/\s/g,'')


          if(state == 1)
            if (fstate != "")
              atom.workspaceView.find('span[data-path="'+fname+'"]').parent().addClass('status-staged')
          #if(state == 2)
            #console.log(2,fstate,fname)

          if (lines[i].indexOf("Changes to be committed:")>=0)
            state=1
          if (lines[i].indexOf("Changes not staged for commit:")>=0)
            state=2
