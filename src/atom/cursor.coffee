{View} = require 'space-pen'
Point = require 'point'
_ = require 'underscore'

module.exports =
class Cursor extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  editor: null
  screenPosition: null
  bufferPosition: null

  initialize: (@editor) ->
    @one 'attach', => @updateAppearance()

  bufferChanged: (e) ->
    @setBufferPosition(e.newRange.end)

  setScreenPosition: (position) ->
    position = Point.fromObject(position)
    @screenPosition = @editor.clipScreenPosition(position)
    @bufferPosition = @editor.bufferPositionForScreenPosition(position)
    @goalColumn = null
    @updateAppearance()
    @trigger 'cursor:position-changed'

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  setBufferPosition: (bufferPosition) ->
    @setScreenPosition(@editor.screenPositionForBufferPosition(bufferPosition))

  refreshScreenPosition: ->
    @setBufferPosition(@bufferPosition)

  getBufferPosition: -> _.clone(@bufferPosition)
  getScreenPosition: -> _.clone(@screenPosition)

  getColumn: ->
    @getScreenPosition().column

  setColumn: (column) ->
    { row } = @getScreenPosition()
    @setScreenPosition {row, column}

  getRow: ->
    @getScreenPosition().row

  isOnEOL: ->
    @getColumn() == @editor.getCurrentLine().length

  moveUp: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - 1, column: column})
    @goalColumn = column

  moveDown: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + 1, column: column})
    @goalColumn = column

  moveToLineEnd: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: @editor.buffer.lineForRow(row).length })

  moveToLineStart: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: 0 })

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition(@editor.clipScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true))

  moveLeft: ->
    { row, column } = @getScreenPosition()

    if column > 0
      column--
    else
      row--
      column = Infinity

    @setScreenPosition({row, column})

  moveLeftUntilMatch: (regex) ->
    row = @getRow()
    column = @getColumn()
    offset = 0

    matchBackwards = =>
      line = @editor.buffer.lineForRow(row)
      reversedLine = line[0...column].split('').reverse().join('')
      regex.exec reversedLine

    if not match = matchBackwards()
      if row > 0
        row--
        column = @editor.buffer.getLineLength(row)
        match = matchBackwards()
      else
        column = 0

    offset = match and -match[0].length or 0

    @setScreenPosition [row, column + offset]

  updateAppearance: ->
    position = @editor.pixelPositionForScreenPosition(@getScreenPosition())
    @css(position)
    @autoScrollVertically(position)
    @autoScrollHorizontally(position)

  autoScrollVertically: (position) ->
    linesInView = @editor.height() / @height()
    maxScrollMargin = Math.floor((linesInView - 1) / 2)
    scrollMargin = Math.min(@editor.vScrollMargin, maxScrollMargin)
    margin = scrollMargin * @height()
    desiredTop = position.top - margin
    desiredBottom = position.top + @height() + margin

    if desiredBottom > @editor.scrollBottom()
      @editor.scrollBottom(desiredBottom)
    else if desiredTop < @editor.scrollTop()
      @editor.scrollTop(desiredTop)

  autoScrollHorizontally: (position) ->
    return if @editor.softWrap

    charsInView = @editor.lines.width() / @width()
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@editor.hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @width()
    cursorLeft = (position.left - @editor.linesPositionLeft())
    desiredRight = cursorLeft + @width() + margin
    desiredLeft = cursorLeft - margin

    if desiredRight > @editor.lines.scrollRight()
      @editor.lines.scrollRight(desiredRight)
    else if desiredLeft < @editor.lines.scrollLeft()
      @editor.lines.scrollLeft(desiredLeft)

