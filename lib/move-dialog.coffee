path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'

_ = require 'underscore-plus'

typeIsArray = Array.isArray || ( value ) ->
  return {}.toString.call( value ) is '[object Array]'

module.exports =
class MoveDialog extends Dialog
  constructor: (@initialPath) ->
    select = true
    if typeIsArray @initialPath
      if @initialPath.length is 1
        @initialPath = @initialPath[0]
      else
        prompt = 'Enter the new path for the files.'
        suggestedPath = @initialPath[0].substring(0, @initialPath[0].lastIndexOf(path.sep))
        suggestedPath += "/"
        select = false
    suggestedPath ?= @initialPath

    if fs.isDirectorySync(@initialPath)
      prompt ?= 'Enter the new path for the directory.'
    else
      prompt ?= 'Enter the new path for the file.'

    super
      prompt: prompt
      initialPath: atom.project.relativize(suggestedPath)
      select: select
      iconClass: 'icon-arrow-right'

  onConfirm: (newPath) ->
    newPath = newPath.replace(/\s+$/, '') # Remove trailing whitespace
    newPath = atom.project.resolve(newPath)
    return unless newPath

    if @initialPath is newPath
      @close()
      return

    unless @isNewPathValid(newPath)
      @showError("'#{newPath}' already exists.")
      return

    console.log newPath
    directoryPath = path.dirname(newPath)
    try
      fs.makeTreeSync(directoryPath) unless fs.existsSync(directoryPath)
      if typeIsArray @initialPath
        _.each(@initialPath, (path) -> fs.moveSync(path, newPath))
      else
        fs.moveSync(@initialPath, newPath)
      if repo = atom.project.getRepo()
        repo.getPathStatus(@initialPath)
        repo.getPathStatus(newPath)
      @close()
    catch error
      @showError("#{error.message}.")

  isNewPathValid: (newPath) ->
    try
      oldStat = fs.statSync(@initialPath)
      newStat = fs.statSync(newPath)

      # New path exists so check if it points to the same file as the initial
      # path to see if the case of the file name is being changed on a on a
      # case insensitive filesystem.
      @initialPath.toLowerCase() is newPath.toLowerCase() and
        oldStat.dev is newStat.dev and
        oldStat.ino is newStat.ino
    catch
      true # new path does not exist so it is valid
