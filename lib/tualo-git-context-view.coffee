{exec} = require 'child_process'
{Directory} = require 'atom';
{File} = require 'atom';

{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
os = require 'os'
crypto = require 'crypto'

# put git language stuff here
texthash =
  state0: [
    "nothing to commit, working directory clean",
    "nichts zu commiten, Arbeitsverzeichnis unverändert",
  ]
  state1: [
    "Changes to be committed:",
    "zum Commit vorgemerkte Änderungen:"
  ]
  state2: [
    "Changes not staged for commit:",
    "Änderungen, die nicht zum Commit vorgemerkt sind:"
  ]
  state3: [
    "Untracked files:",
    "Unbeobachtete Dateien:"
  ]

module.exports =
class TualoGitContextView

  constructor: (serializeState) ->



    @messageElement = document.createElement('div')
    @messageElement.classList.add('tualo-git-context')
    @message = document.createElement('div')
    @message.textContent = ""
    @message.classList.add('default-message')
    @messageElement.appendChild(@message)

    @statusNew = {}
    @statusChanged = {}
    @statusStaged = {}
    @statusIgnored = {}
    @statusClean = {}

    @branches = {}
    @remote = ""
    @commitMsgCallback = null



    @commitMessageFilePath = '.commitmessage'
    paths = atom.project.getPaths()
    #if paths.length > 0
    #  @commitMessageFilePath = path.join paths[0],'.commitmessage'
    #else
    @commitMessageFilePath = path.join os.tmpdir(),'.commitmessage'

    @myDisposables = []

    atom.workspace.onDidOpen (event) =>
      if @getRepository()
        shortFilePath = event.uri.substring @getRepository().getWorkingDirectory().length+1
        @gitStatus shortFilePath

    atom.workspace.observeTextEditors (editor) =>
      if @getRepository()
        @myDisposables.push editor.onDidSave (event) =>
          if event.path == @commitMessageFilePath or
             event.path == '/private'+@commitMessageFilePath
            atom.workspace.destroyActivePaneItem()
            if typeof @commitMsgCallback == 'function'
              @commitMsgCallback()
          shortFilePath = event.path.substring @getRepository().getWorkingDirectory().length+1
          @gitStatus shortFilePath

    @getRemote()
    @refreshTree()


  getRepository: ->
    repos = atom.project.getRepositories()
    if repos.length>0
      return repos[0]


  serialize: ->

  # Tear down any state and detach
  destroy: ->
    for i in [0...@myDisposables.length]
      @myDisposables[i].dispose()
    @messageElement.remove()
    @detach()

  getMessageElement: ->
    @messageElement
  getMessage: ->
    @message

  getCommitFilePath: ->
    @commitMessageFilePath
  setCommitCallback: (cb) ->
    @commitMsgCallback = cb

  checkLine: (line,stateTexts) ->
    res = false
    (res = true for txt  in stateTexts when line.indexOf(txt)>=0)
    res

  getRemote: ()->
    me = @
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      exec 'git remote',options, (err,stdout,stderr) =>
        if not err?
          me.remote = stdout.replace(/\n/gim,"")

  getBranches: ()->
    me = @
    if @getRepository()
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      exec 'git show-branch --list',options, (err,stdout,stderr) =>
        if not err?
          lines = stdout.split("\n")
          for i in [0...lines.length]
            p = lines[i].split("]")
            if p.length > 1
              current = false
              if p[0].indexOf('*')==0
                current = true
              x = p[0].split("[")
              opt =
                current: current
              me.branches[x[1]] = opt


  gitStatus: (fileName)->
    me = @
    if @getRepository()
      fileName = fileName.replace("\n","")
      longName = @getRepository().getWorkingDirectory()+'/'+fileName
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000

      if fs.existsSync(longName)
        if fs.lstatSync(longName).isDirectory()
          me.refreshTree()
        else
          exec 'git status "'+fileName+'"',options, (err,stdout,stderr) =>
            lines = stdout.split("\n")
            state = 0
            for i in [0...lines.length]
              p = lines[i].indexOf(":")
              if state == 3
                fname = lines[i]#.replace(/\s/g,'')
              else
                fstate = lines[i].substring(0,p)#.replace(/\s/g,'')
                fname = lines[i].substring(p+1)#.replace(/\s/g,'')
              if me.checkLine(lines[i],texthash.state0)
                state=0
              if me.checkLine(lines[i],texthash.state1)
                state=1
              if me.checkLine(lines[i],texthash.state2)
                state=2
              if me.checkLine(lines[i],texthash.state3)
                state=3
                i++
            queryName = longName.replace(/"/g,'*')
            entryNode = document.querySelector('span[data-path="'+queryName+'"]')
            if typeof entryNode != 'undefined' && entryNode != null

              delete  me.statusClean[longName];
              delete  me.statusIgnored[longName];
              delete  me.statusNew[longName];
              delete  me.statusChanged[longName];
              delete  me.statusStaged[longName];

              oldNames = entryNode.className.split(' ')
              newNames = []
              for o in [0...oldNames.length]
                if oldNames[o] == 'tualo-git-context-nothing'
                else if oldNames[o] == 'tualo-git-context-new'
                else if oldNames[o] == 'tualo-git-context-staged'
                else if oldNames[o] == 'tualo-git-context-changed'
                else
                  newNames.push(oldNames[o])

              if state == 0
                me.statusClean[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-nothing')

              if state == 1
                me.statusStaged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-staged')

              if state == 2
                me.statusChanged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-changed')

              if state == 3
                me.statusNew[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-new')

              entryNode.className = newNames.join(' ')

  refreshClean: (directory) ->

    directory.getEntries (err,list) =>
      if (err)
      else
        for i in [0...list.length]
          #console.log list[i].path.substring(directory.path.length)
          if list[i] instanceof File
            longName = list[i].path.replace("\n","")
            if typeof @statusNew[longName]=='undefined' and
            typeof @statusChanged[longName]=='undefined' and
            typeof @statusStaged[longName]=='undefined'
              try
                entryNode = document.querySelector('span[data-path="'+longName+'"]')
                if typeof entryNode != 'undefined' && entryNode != null
                  @statusClean[longName] =
                    entryNode: entryNode
                else
                  @statusIgnored[longName] =
                    entryNode: entryNode
              catch e
                console.log e
          else if list[i] instanceof Directory
            if list[i].path.substring(directory.path.length).substring(0,5)!='/.git'
              @refreshClean list[i]


  refreshTree: () ->
    me = @
    if @getRepository()
      @getBranches()
      gitdir = @getRepository().getWorkingDirectory()
      options =
        cwd: gitdir
        timeout: 30000
      exec 'git status',options, (err,stdout,stderr) =>
        lines = stdout.split("\n")
        state = 0
        for i in [0...lines.length]
          p = lines[i].indexOf(":")
          fname=''
          fstate=''
          if state == 3
            fname = lines[i].replace(/\s/g,'')
          else
            fstate = lines[i].substring(0,p).replace(/\s/g,'')
            fname = lines[i].substring(p+1).replace(/\s/g,'')
          if me.checkLine(lines[i],texthash.state0)
            state=0
          if me.checkLine(lines[i],texthash.state1)
            state=1
          if me.checkLine(lines[i],texthash.state2)
            state=2
          if me.checkLine(lines[i],texthash.state3)
            state=3
            i++
          if (state==3 || fstate!='') and
          lines[i].indexOf("\t")==0
            longName = gitdir + '/' + fname
            queryName = longName.replace(/"/g,"*")
            #console.log longName,queryName
            entryNode = document.querySelector('span[data-path="'+queryName+'"]')
            if typeof entryNode != 'undefined' && entryNode != null

              delete  me.statusClean[longName];
              delete  me.statusIgnored[longName];
              delete  me.statusNew[longName];
              delete  me.statusChanged[longName];
              delete  me.statusStaged[longName];

              oldNames = entryNode.className.split(' ')
              newNames = []
              for o in [0...oldNames.length]
                if oldNames[o] == 'tualo-git-context-nothing'
                else if oldNames[o] == 'tualo-git-context-new'
                else if oldNames[o] == 'tualo-git-context-staged'
                else if oldNames[o] == 'tualo-git-context-changed'
                else
                  newNames.push(oldNames[o])


              if state == 1
                me.statusStaged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-staged')

              if state == 2
                me.statusChanged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-changed')

              if state == 3
                me.statusNew[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-new')

              entryNode.className = newNames.join(' ')

        root = atom.project.getDirectories()[0]
        if root
          @refreshClean root
