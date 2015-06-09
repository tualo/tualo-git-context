{exec} = require 'child_process'
{Directory} = require 'atom';
{File} = require 'atom';

{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

module.exports =
class TualoGitContextView

  constructor: (serializeState) ->



    @messageElement = document.createElement('div')
    @messageElement.classList.add('tualo-git-context')
    @message = document.createElement('div')
    @message.textContent = ""
    @message.classList.add('default-message')
    @messageElement.appendChild(@message)

    @statusNew = {};
    @statusChanged = {};
    @statusStaged = {};
    @statusIgnored = {};
    @statusClean = {};

    @commitMsgCallback = null



    @commitMessageFilePath = '/tmp/.commitmessage'
    paths = atom.project.getPaths()
    if path.length > 0
      @commitMessageFilePath = path.join paths[0],'.commitmessage'

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

  gitStatus: (fileName)->
    if @getRepository()
      longName = @getRepository().getWorkingDirectory()+'/'+fileName
      options =
        cwd: @getRepository().getWorkingDirectory()
        timeout: 30000
      exec 'git status '+fileName,options, (err,stdout,stderr) =>
        lines = stdout.split("\n")
        state = 0
        for i in [0...lines.length]
          p = lines[i].indexOf(":")
          if state == 3
            fname = lines[i].replace(/\s/g,'')
          else
            fstate = lines[i].substring(0,p).replace(/\s/g,'')
            fname = lines[i].substring(p+1).replace(/\s/g,'')
          if (lines[i].indexOf("nothing to commit, working directory clean")>=0)
            state=0
          if (lines[i].indexOf("Changes to be committed:")>=0)
            state=1
          if (lines[i].indexOf("Changes not staged for commit:")>=0)
            state=2
          if (lines[i].indexOf("Untracked files:")>=0)
            state=3
            i++
        entryNode = document.querySelector('span[data-path="'+longName+'"]')
        if typeof entryNode != 'undefined' && entryNode != null

          delete  @statusClean[longName];
          delete  @statusIgnored[longName];
          delete  @statusNew[longName];
          delete  @statusChanged[longName];
          delete  @statusStaged[longName];

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
            @statusClean[longName] =
              entryNode: entryNode
            newNames.push('tualo-git-context-nothing')

          if state == 1
            @statusStaged[longName] =
              entryNode: entryNode
            newNames.push('tualo-git-context-staged')

          if state == 2
            @statusChanged[longName] =
              entryNode: entryNode
            newNames.push('tualo-git-context-changed')

          if state == 3
            @statusNew[longName] =
              entryNode: entryNode
            newNames.push('tualo-git-context-new')

          entryNode.className = newNames.join(' ')

  refreshClean: (directory) ->

    directory.getEntries (err,list) =>
      if (err)
      else
        for i in [0...list.length]
          if list[i] instanceof File
            longName = list[i].path
            if typeof @statusNew[longName]=='undefined' and
            typeof @statusChanged[longName]=='undefined' and
            typeof @statusStaged[longName]=='undefined'
              entryNode = document.querySelector('span[data-path="'+longName+'"]')
              if typeof entryNode != 'undefined' && entryNode != null
                @statusClean[longName] =
                  entryNode: entryNode
              else
                @statusIgnored[longName] =
                  entryNode: entryNode
          else if list[i] instanceof Directory
            if list[i].path.substring(0,4)=='.git'
              @refreshClean list[i]


  refreshTree: (dir) ->
    if @getRepository()
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
          if lines[i].indexOf("nothing to commit, working directory clean")>=0 or
             lines[i].indexOf("nichts zu commiten, Arbeitsverzeichnis unverändert")>=0
            state=0
          if lines[i].indexOf("Changes to be committed:")>=0 or
             lines[i].indexOf("zum Commit vorgemerkte Änderungen:")>=0
            state=1
          if lines[i].indexOf("Changes not staged for commit:")>=0 or
             lines[i].indexOf("Änderungen, die nicht zum Commit vorgemerkt sind:")>=0
            state=2
          if lines[i].indexOf("Untracked files:") >= 0 or
             lines[i].indexOf("Unbeobachtete Dateien:") >= 0
            state=3
            i++
          if (state==3 || fstate!='') and
          lines[i].indexOf("\t")==0
            longName = gitdir + '/' + fname
            entryNode = document.querySelector('span[data-path="'+longName+'"]')
            if typeof entryNode != 'undefined' && entryNode != null

              delete  @statusClean[longName];
              delete  @statusIgnored[longName];
              delete  @statusNew[longName];
              delete  @statusChanged[longName];
              delete  @statusStaged[longName];

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
                @statusStaged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-staged')

              if state == 2
                @statusChanged[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-changed')

              if state == 3
                @statusNew[longName] =
                  entryNode: entryNode
                newNames.push('tualo-git-context-new')

              entryNode.className = newNames.join(' ')

        root = atom.project.getDirectories()[0]
        if root
          @refreshClean root
