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

    console.log 'debug'
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
      shortFilePath = event.uri.substring @getRepository().getWorkingDirectory().length+1
      @gitStatus shortFilePath

    atom.workspace.observeTextEditors (editor) =>

      @myDisposables.push editor.onDidSave (event) =>
        if event.path == @commitMessageFilePath
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

    for i in [0...myDisposables.length]
      @myDisposables[i].dispose()

    @element.remove()
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
        for i in [0...oldNames.length]
          if oldNames[i] == 'tualo-git-context-nothing'
          else if oldNames[i] == 'tualo-git-context-new'
          else if oldNames[i] == 'tualo-git-context-staged'
          else if oldNames[i] == 'tualo-git-context-changed'
          else
            newNames.push(oldNames[i])

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

  refreshTree: (dir) ->
    if typeof dir == 'undefined'
      dirs = atom.project.getDirectories()
      for i in [0...dirs.length]
        @refreshTree dirs[i]
    else
      if (dir instanceof Directory)
        path = dir.path
        if path.substring(path.length-4)!='.git' # don't search git it self
          dir.getEntries (error,entries) =>
            for f in [0...entries.length]
              if entries[f] instanceof File
                shortFilePath = entries[f].path.substring @getRepository().getWorkingDirectory().length+1
                @gitStatus shortFilePath
              if entries[f] instanceof Directory
                @refreshTree entries[f]
