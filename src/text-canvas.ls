module.exports = class TextCanvas
  (@R, @C, {char ? ' ', style ? null}:fill = {}) ->
    @canvas = for r til R => for c til C => {char, style}

  # place a text block onto this canvas
  #   src: either:
  #     [][]char
  #     []string
  #     string (newline-separated)
  #     TextCanvas
  #   opt:
  #     style:
  #       Object -- per-char style object applied to the whole block
  #       [][]Object -- style object associated with each `src` cell
  #     transparent: string -- characters in it are not painted
  #       `opt.style` is also not painted
  #     left/right/top/bottom: number -- inclusive limits of paint region
  #     hAlign: 'left' or 'center' or 'right'
  #       'left' and 'center': must specify `opt.left`
  #       'right' and 'center: must specify `opt.right`
  #       default: 'left' if `opt.left` specified; 'right' ditto
  #     vAlign: 'top' or 'center' or 'bottom'
  #       'top' and 'center': must specify `opt.top`
  #       'bottom' and 'center: must specify `opt.bottom`
  #       default: 'top' if `opt.top` specified; 'bottom' ditto
  #     overflow/hOverflow/vOverflow: 'clip' or 'overwrite'
  #       `opt.overflow` sets default value for both horizontal and vertical
  #       'clip': must specify both limits on this axis
  #     margin/hMargin/vMargin: Integer
  #       ignored if `opt.hAlign` is 'center' on this axis
  #       `opt.margin` sets default value for both horizontal and vertical
  #       if both indices on this axis specified:
  #         try reduce margin to prevent overflow:
  #             012345
  #           1   a
  #           2   ab
  #           3   abc
  #           4  abcd
  #           5 abcde
  #           6 abcdef
  draw: (src, opt) !->
    if typeof src is \string
      # text block => array of lines
      # NOTE: EOL on the last line is stripped
      src .= split '\n'
      if src[*-1].trim!length == 0 then src.pop!
    else if src instanceof TextCanvas
      # another TextCanvas => override style
      style = for r til src.R => for c til src.C => src[r][c].style
      src = for r til src.R => for c til src.C => src[r][c].char

    # src bounding box
    srcW = Math.max ...(src.map (.length))
    srcH = src.length

    # positioning

    {
      left, right, top, bottom
      hAlign, vAlign

      overflow ? \overwrite
      hOverflow ? overflow
      vOverflow ? overflow

      margin ? 0
      hMargin ? margin
      vMargin ? margin
    } = opt
    if !hAlign?
      if left? then hAlign = \left
      else if right? then hAlign = \right
    if !vAlign?
      if top? then vAlign = \top
      else if bottom? then vAlign = \bottom

    function centerOffset(spaceLen, contentLen)
      (spaceLen - contentLen).>>.1
    function rightOffset(spaceLen, contentLen)
      (spaceLen - contentLen)
    function marginOffset(maxMargin, spaceLen, contentLen)
      (maxMargin - ((contentLen + maxMargin - spaceLen) >? 0)) >? 0

    # reuse code because 2x2 parallel code is too cumbersome
    # NOTE: sub-function shadows ids {margin, overflow}
    [c1, c2] = handleAlign(hAlign, left, right, srcW, hMargin, hOverflow)
    [r1, r2] = handleAlign(vAlign, top, bottom, srcH, vMargin, vOverflow)
    function handleAlign(align, lo, hi, srcL, margin, overflow)
      switch align
      | \left \top
        if margin > 0 and hi?
          offset = marginOffset(margin, hi - lo + 1, srcL) # >= 0
        else
          offset = 0
        x1 = lo + offset
        x2 = x1 + srcL - 1
        if overflow == \clip
          x1 >?= lo
          if hi? then x2 <?= hi
      | \center
        offset = centerOffset(hi - lo + 1, srcL)
        x1 = lo + offset
        x2 = x1 + srcL - 1
        if overflow == \clip
          x1 >?= lo
          x2 <?= hi
      | \right \bottom
        # inverted parallel code of \lo
        if margin > 0 and lo?
          offset = marginOffset(margin, hi - lo + 1, srcL) # >= 0
        else
          offset = 0
        x2 = hi - offset
        x1 = x2 - srcL + 1
        if overflow == \clip
          x2 <?= hi
          if lo? then x1 >?= lo
      #end switch
      [x1, x2]
    #end function handleAlign

    # finally draw it
    {transparent ? ''} = opt
    style ?= opt.style
    styleIsArr = style?.0?.0?
    r1 >?= 0 ; r2 <?= @R - 1
    c1 >?= 0 ; c2 <?= @C - 1
    for r from r1 to r2
      for c from c1 to c2
        char = src[r - r1][c - c1]
        style1 = if styleIsArr then style[r - r1][c - c1] else style
        if !char? or char in transparent then continue
        @canvas[r][c] <<< {char, style: style1}

  #end function draw

  # return: plain-text string
  # style: (ignored)
  renderPlain: ->
    ret = ''
    {R, C, canvas} = @
    for r til R
      for c til C
        ret += canvas[r][c].char
      ret += '\n'
    ret

  # return: string with terminal styling
  # style: ?{open: string, close: string}
  # NOTE: this can also be used to generate non-optimal HTML
  renderTerm: ->
    {R, C, canvas} = @
    ret = ''
    for r til R
      last = null
      for c til C
        with canvas[r][c]
          with ..style
            if .. != last
              ret += (last?.close ? '') + (..?open ? '')
              last = ..
          ret += ..char
      ret += (last?.close ? '') + '\n'
    ret

  # call `console.log`; applying devtools styling in supported browsers
  # style: ?{css: string} or ?string
  renderConsole: !->
    if not window?.navigator?
      return console.log @renderPlain!

    # adapted from https://github.com/icodeforlove/Console.js (MIT Licensed)
    browser = {}
    browser.isFirefox = /firefox/i.test(navigator.userAgent)
    browser.isIE = document.documentMode
    support = {}
    support.console = !!window.console
    support.modifiedConsole = !browser.isIE && support.console && console.log.toString().indexOf('apply') !== -1
    support.consoleStyles = !!window.chrome || !!(browser.isFirefox && support.modifiedConsole)

    if not (support.console and support.consoleStyles)
      return console.log @renderPlain!

    {R, C, canvas} = @
    # build arguments
    main = ''
    args = [null]
    # mostly parallel of `renderTerm`
    for r til R
      last = null
      for c til C
        with canvas[r][c]
          with ..style
            if .. != last
              main += '%c'
              args.push ..?css ? .. ? ''
              last = ..
          main += ..char
      main += '\n'
    # make the call
    args.0 = main
    console.log ...args
