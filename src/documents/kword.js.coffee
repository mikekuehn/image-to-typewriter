
charset =

  previewCanvas: document.getElementById('charsetPreview') # onscreen display of charset (keystoned and cropped)
  overlayCanvas: document.getElementById('charsetOverlay') # onscreen display of chopping grid / selected chars
  workingCanvas: document.createElement('canvas') # in memory canvas for hi-res operations

  settings: # defined by user input from onscreen
    gridSize: [20,20] # [x,y] number of columns,rows in between (not including) keystones
    offset: [] # [x,y] multiples of character size to offset right and down, compensates for keystone centers
    start: [] # [x,y] position on grid of the top left character in the desired charset, in [column,row] (start from 0)
    end: [] # [x,y] position on grid of the bottom right character in the desired charset, in [column,row] (start from 0)

  chars: [] # array of individual objects

  combos: [] # array of character combo objects

  # quadrant width and height in px
  qWidth: 0
  qHeight: 0




  getSettings: ->
    formValues = {}

    for formField in ['rows','cols','rowStart','rowEnd','colStart','colEnd','offsetX','offsetY']
      formValues[formField] = document.getElementById(formField).value

    charset.settings.gridSize = [(formValues.cols/1)+1,(formValues.rows/1)+1]
    charset.settings.offset = [formValues.offsetX,formValues.offsetY]
    charset.settings.start = [formValues.colStart,formValues.rowStart]
    charset.settings.end = [formValues.colEnd,formValues.rowEnd]







  # previews chop grid settings on an overlay canvas
  chopPreview: -> 
    ctx = charset.overlayCanvas.getContext('2d')

    charWidth = charset.overlayCanvas.width / charset.settings.gridSize[0]
    charHeight = charset.overlayCanvas.height / charset.settings.gridSize[1]
    offsetX = charWidth * charset.settings.offset[0]
    offsetY = charHeight * charset.settings.offset[1]

    start = [charset.settings.start[0]*charWidth+offsetX,charset.settings.start[1]*charHeight+offsetY]
    end = [charset.settings.end[0]*charWidth+2*offsetX,charset.settings.end[1]*charHeight+2*offsetY]

    lightboxSelection = ->
      ctx.clearRect(0, 0, charset.overlayCanvas.width, charset.overlayCanvas.height)
      ctx.fillStyle = "rgba(0,0,0,0.75)"
      ctx.fillRect(0, 0, charset.overlayCanvas.width, charset.overlayCanvas.height)
      ctx.clearRect(start[0],start[1],end[0]-start[0]+offsetX,end[1]-start[1]+offsetY)

    lightboxSelection()

    # TODO fix this
    drawGrid = ->
      numRows = (charset.settings.end[1] - charset.settings.start[1])
      numCols = (charset.settings.end[0] - charset.settings.start[0])
      for row in [0..numRows+1]
        # horizontal lines
        ctx.beginPath();
        ctx.moveTo(start[0],start[1]+row*charHeight);
        ctx.lineTo(end[0]+offsetX,start[1]+row*charHeight);
        ctx.strokeStyle = "rgba(255,0,0,0.5)"
        ctx.stroke();
      for col in [0..numCols+1]
        # vertical lines
        ctx.beginPath();
        ctx.moveTo(start[0]+col*charWidth,start[1]);
        ctx.lineTo(start[0]+col*charWidth,end[1]+offsetY);
        ctx.strokeStyle = "rgba(255,0,0,0.5)"
        ctx.stroke();

    drawGrid()






  chopCharset: ->
    # resize workingCanvas to nearest multiple of rows, cols and redraw
    resizeCanvasToMultiplesOfCharSize = ->
      wCanvas = charset.workingCanvas
      tempCanvas = document.createElement('canvas')
      tempCanvas.width = wCanvas.width
      tempCanvas.height = wCanvas.height

      # save workingCanvas into tempCanvas
      tempCanvas.getContext('2d').drawImage(wCanvas, 0, 0);

      # get closest multiple
      newWidth = Math.ceil((charset.workingCanvas.width/(charset.settings.gridSize[0])/4)) * charset.settings.gridSize[0] * 4
      newHeight = Math.ceil((charset.workingCanvas.height/(charset.settings.gridSize[1])/4)) * charset.settings.gridSize[1] * 4

      # resize workingCanvas
      wCanvas.width = newWidth
      wCanvas.height = newHeight

      # draw tempCanvas back into workingCanvas, scaled as needed
      wCanvas.getContext('2d').drawImage(tempCanvas, 0, 0, tempCanvas.width, tempCanvas.height, 0, 0, wCanvas.width, wCanvas.height)

    resizeCanvasToMultiplesOfCharSize()

    charset.chars = []
    ctx = charset.workingCanvas.getContext('2d')
    charWidth = charset.workingCanvas.width / charset.settings.gridSize[0]
    charHeight = charset.workingCanvas.height / charset.settings.gridSize[1]
    offsetX = charWidth * charset.settings.offset[0]
    offsetY = charHeight * charset.settings.offset[1]
    start = [charset.settings.start[0]*charWidth+offsetX,charset.settings.start[1]*charHeight+offsetY]
    numRows = (charset.settings.end[1] - charset.settings.start[1])
    numCols = (charset.settings.end[0] - charset.settings.start[0])

    charset.qWidth = charWidth/2
    charset.qHeight = charHeight/2

    # loop through characters push new char objects to the chars array
    for row in [0..numRows]
      for col in [0..numCols]
        # top left corner location of character glyph in the charset working image
        startChar = [start[0]+charWidth*col,start[1]+charHeight*row]
        # image data for quadrants
        TL = ctx.getImageData( \
          Math.floor(startChar[0]), Math.floor(startChar[1]), \
          Math.floor(charset.qWidth), Math.floor(charset.qHeight) )
        TR = ctx.getImageData( \
          Math.floor(startChar[0]+charWidth/2),Math.floor(startChar[1]), \
          Math.floor(charset.qWidth), Math.floor(charset.qHeight) )
        BL = ctx.getImageData( \
          Math.floor(startChar[0]), Math.floor(startChar[1]+charset.qHeight), \
          Math.floor(charset.qWidth), Math.floor(charset.qHeight) )
        BR = ctx.getImageData( \
          Math.floor(startChar[0]+charset.qWidth), Math.floor(startChar[1]+charset.qHeight), \
          Math.floor(charset.qWidth), Math.floor(charset.qHeight) )
        charset.chars.push new Char(TL,TR,BL,BR)

    # invert and nomalize brightness
    
    maxBright = _.max(charset.chars,(w) -> w.brightness).brightness
    minBright = _.min(charset.chars,(w) -> w.brightness).brightness
    for char in charset.chars
      char.brightness = 255 - (255*(char.brightness-minBright))/(maxBright-minBright)

    # sort chars array by char.brightness
    charset.chars = _(charset.chars).sortBy('brightness')

    # now create indexes to correlate with combo objects
    for i in [0...charset.chars.length]
      charset.chars[i].index = i
      
    # do not change character indexes after this!



  drawCharQuadrants: ->
    $('#charQuadrants').empty()
    for i in [0...charset.chars.length]
      char = charset.chars[i]

      drawQuadrant = (quadrant,quadrantString) ->
        # create canvas
        newCanvasHtml = '<canvas id="char'+quadrantString+i+'" width="'+charset.qWidth+'" height="'+charset.qHeight+'"></canvas>'
        $('#charQuadrants').append newCanvasHtml
        cvs = document.getElementById('char'+quadrantString+i)
        ctx = cvs.getContext("2d")

        ctx.putImageData(quadrant,0,0)

      drawQuadrant(char.TL,"TL")
      drawQuadrant(char.TR,"TR")
      drawQuadrant(char.BL,"BL")
      drawQuadrant(char.BR,"BR")


  drawCharSelect: ->
    $('#viewSelect').empty()
    for i in [0...charset.chars.length]

      char = charset.chars[i]

      # redundant spaces removed from preview
      # min, median and max characters selected
      spaceWeight
      if i is 0
        spaceWeight = char.brightness
        char.selected = true
      else if Math.abs(char.brightness-spaceWeight) < 20
        continue
      if i is charset.chars.length-1
        char.selected = true
      if i is Math.round(charset.chars.length*0.5)
        char.selected = true

      # create canvas
      newCanvasHtml = '<canvas id="char'+i+'" width="'+charset.qWidth*2+'" height="'+charset.qHeight*2+'"></canvas>'
      $('#viewSelect').append newCanvasHtml
      cvs = document.getElementById('char'+i)
      ctx = cvs.getContext("2d")


      # draw 4 quadrants of char

      drawChar = (char,ctx) ->
        # redraw 4 quadrants
        ctx.putImageData(char.TL,0,0)
        ctx.putImageData(char.TR,charset.qWidth,0)
        ctx.putImageData(char.BL,0,charset.qHeight)
        ctx.putImageData(char.BR,charset.qWidth,charset.qHeight)
        
        if ! char.selected
          ctx.fillStyle = "rgba(0,0,0,0.5)"
          ctx.fillRect(0, 0, charset.qWidth*2, charset.qHeight*2)


      drawChar(char,ctx)



      makeClickHandler = (char,ctx) ->
        $('#char'+i).click ( (e) ->
          char.selected = !char.selected
          # redraw greyed out if unselected
          ctx.clearRect(0, 0, charset.qWidth*2, charset.qHeight*2)

          drawChar(char,ctx)

        )

      makeClickHandler(char,ctx)

      










  genCombos: ->

    # clear combo preview
    $('#comboPreview').empty()

    # Generate array of combo objects
    # Indices correspond to the indices of the 
    # chars composing the combo [TL][TR][BL][BR]
    combos = []

    # restrict to selected characters
    selected = [] 
    for c in charset.chars
      if c.selected
        selected.push(c)

    # Generate all possible combos
    for a in [0...selected.length]
      combos.push []
      for b in [0...selected.length]
        combos[a].push []
        for c in [0...selected.length]
          combos[a][b].push []
          for d in [0...selected.length]
            combos[a][b][c].push new Combo(a,b,c,d,charset,selected);

    charset.combos = combos

    minBright = 100000000 # implausibly bright for a minimum
    maxBright = 0   # implausibly dark for a maximum

    # find min and max brightness for each quadrant of the quadrant!
    for a in [0...selected.length]
      for b in [0...selected.length]
        for c in [0...selected.length]
          for d in [0...selected.length]
            bright = charset.combos[a][b][c][d].TLbrightness
            if bright>maxBright
              maxBright = bright
            if bright<minBright
              minBright = bright
            bright = charset.combos[a][b][c][d].TRbrightness
            if bright>maxBright
              maxBright = bright
            if bright<minBright
              minBright = bright
            bright = charset.combos[a][b][c][d].BLbrightness
            if bright>maxBright
              maxBright = bright
            if bright<minBright
              minBright = bright
            bright = charset.combos[a][b][c][d].BRbrightness
            if bright>maxBright
              maxBright = bright
            if bright<minBright
              minBright = bright

    # normalize and invert brightness
    for a in [0...selected.length]
      for b in [0...selected.length]
        for c in [0...selected.length]
          for d in [0...selected.length]
            combo = charset.combos[a][b][c][d]
            combo.brightness = 255 - (255*(combo.brightness-minBright))/(maxBright-minBright)
            combo.TLbrightness = 255 - (255*(combo.TLbrightness-minBright))/(maxBright-minBright)
            combo.TRbrightness = 255 - (255*(combo.TRbrightness-minBright))/(maxBright-minBright)
            combo.BLbrightness = 255 - (255*(combo.BLbrightness-minBright))/(maxBright-minBright)
            combo.BRbrightness = 255 - (255*(combo.BRbrightness-minBright))/(maxBright-minBright)
    ###

    # invert brightness
    for a in [0...selected.length]
      for b in [0...selected.length]
        for c in [0...selected.length]
          for d in [0...selected.length]
            combo = charset.combos[a][b][c][d]
            combo.brightness = 255 - (255*(combo.brightness)/maxBright)
            combo.TLbrightness = 255 - (255*(combo.TLbrightness)/maxBright)
            combo.TRbrightness = 255 - (255*(combo.TRbrightness)/maxBright)
            combo.BLbrightness = 255 - (255*(combo.BLbrightness)/maxBright)
            combo.BRbrightness = 255 - (255*(combo.BRbrightness)/maxBright)
    ###



    drawCombos = ->
      # remove existing combo images from DOM
      $('#comboPreview').empty()

      # store all combos to be drawn in this 1d array (for sorting)
      sortedCombos = []
      
      for a in [0...selected.length]
        for b in [0...selected.length]
          for c in [0...selected.length]
            for d in [0...selected.length]
              # add to new output array 
              sortedCombos.push charset.combos[a][b][c][d]


      # sort the combos
      sortedCombos = _(sortedCombos).sortBy('brightness')

      # create a unique DOM element for each combo image
      # TODO this is slow... should reduce # of dom accesses
      id = 0
      for combo in sortedCombos
        # create canvas
        newCanvasHtml = '<canvas id="combo'+id+'" width="'+charset.qWidth+'" height="'+charset.qHeight+'"></canvas>'
        $('#comboPreview').append newCanvasHtml
        cvs = document.getElementById('combo'+id)
        ctx = cvs.getContext("2d")
        ctx.putImageData(combo.image,0,0)
        id++

    drawCombos()

    charset.selected = selected







  dropImage: (source) ->
    MAX_HEIGHT = $(window).height() - 100 

    render = (src) ->

      image = new Image

      image.onload = ->
        canvas = charset.previewCanvas
        if image.height > MAX_HEIGHT
          image.width *= MAX_HEIGHT / image.height
          image.height = MAX_HEIGHT
        ctx = canvas.getContext('2d')
        ctx.clearRect 0, 0, canvas.width, canvas.height
        canvas.width = image.width
        canvas.height = image.height
        ctx.drawImage image, 0, 0, image.width, image.height
        #resize overlay to match
        canvas = charset.overlayCanvas
        canvas.width = image.width
        canvas.height = image.height
        return

      image.src = src
      return

    renderWorking = (src) ->

      image = new Image

      image.onload = ->
        canvas = charset.workingCanvas
        ctx = canvas.getContext('2d')
        ctx.clearRect 0, 0, canvas.width, canvas.height
        canvas.width = image.width
        canvas.height = image.height
        ctx.drawImage image, 0, 0, image.width, image.height
        return

      image.src = src
      return

    loadImage = (src) ->
      # Prevent any non-image file type from being read.
      if !src.type.match(/image.*/)
        console.log 'The dropped file is not an image: ', src.type
        return
      # Create our FileReader and run the results through the render function.
      reader = new FileReader

      reader.onload = (e) ->
        render e.target.result
        renderWorking e.target.result
        return

      reader.readAsDataURL src
      return

    loadImage(source)




# this will be populated as a 2d array (rows, cols) of charset.selected indices
combosArray = []
bestCombos = []

imgToText = ->
  combosArray = []
  bestCombos = []
  source = document.getElementById("inputImage")
  cvs = source.getContext('2d')
  dither = document.getElementById('dithering').checked
  considerSpill = document.getElementById('considerSpill').checked
  gr = greyscale(source)
  [h,w] = [source.height,source.width]
  # looping through input image array in 2x2 pixel increments
  for i in [0...h] by 2
    row = []
    comboRow = []
    for j in [0...w] by 2
      # weigh subpixels of input image
      bTL = gr[i*w + j] # brightness value of input image subpixel
      bTR = gr[i*w + j+1] # brightness value of input image subpixel
      bBL = gr[(i+1)*w + j] # brightness value of input image subpixel
      bBR = gr[(i+1)*w + j+1] # brightness value of input image subpixel

      # weigh subpixels of input image - spill to the right
      bTLr = gr[i*w + j+3] # brightness value of input image subpixel
      bTRr = gr[i*w + j+4] # brightness value of input image subpixel
      bBLr = gr[(i+1)*w + j+3] # brightness value of input image subpixel
      bBRr = gr[(i+1)*w + j+4] # brightness value of input image subpixel

      # weigh subpixels of input image - spill to the bottom
      bTLb = gr[(i+2)*w + j] # brightness value of input image subpixel
      bTRb = gr[(i+2)*w + j+1] # brightness value of input image subpixel
      bBLb = gr[(i+3)*w + j] # brightness value of input image subpixel
      bBRb = gr[(i+3)*w + j+1] # brightness value of input image subpixel

      # weigh subpixels of input image - spill to the bottom right
      bTLbr = gr[(i+2)*w + j+3] # brightness value of input image subpixel
      bTRbr = gr[(i+2)*w + j+4] # brightness value of input image subpixel
      bBLbr = gr[(i+3)*w + j+3] # brightness value of input image subpixel
      bBRbr = gr[(i+3)*w + j+4] # brightness value of input image subpixel
      
      # establish constraints on character selection
      TL=TR=BL=0
      if i>0 and j>0
        TL=combosArray[i/2-1][j/2-1]
      if i>0
        TR=combosArray[i/2-1][j/2]
      if j>0
        BL=row[row.length-1]
      

      # find closest ascii brightness value
      # closest is the index in charset.selected of the best char choice
      closest = 0
      bestErr = 0
      bestCombo = null

      # how much should the spill be considered?
      spillRatioRight = $('#spillRatioRight').val() * $('#spillRatio').val()
      spillRatioBottomRight = $('#spillRatioBottomRight').val() * $('#spillRatio').val()
      spillRatioBottom = $('#spillRatioBottom').val() * $('#spillRatio').val()


      # how much brighter should the spill be?
      spillBrightness = 1 - $('#spillBrightness').val()

      # loop through appropriate subsection of combos and weigh each subpixel against the input image
      for k in [0...charset.combos[TL][TR][BL].length]
        
        combo = charset.combos[TL][TR][BL][k]

        # get spill images
        spillBottom = charset.combos[0][k][0][0]
        spillRight = charset.combos[0][0][k][0]
        spillBottomRight = charset.combos[k][0][0][0]

        # check each subpixel against input image
        # save subpixel errors separately to avoid including spill in dithering
        errTL = errTL1 = bTL-combo.TLbrightness
        errTR = errTR1 = bTR-combo.TRbrightness
        errBL = errBL1 = bBL-combo.BLbrightness
        errBR = errBR1 = bBR-combo.BRbrightness
        errTot = errTot1 = (errTL+errTR+errBL+errBR)/4

        # compare spill areas
        errTL = bTLb*spillBrightness-spillBottom.TLbrightness
        errTR = bTRb*spillBrightness-spillBottom.TRbrightness
        errBL = bBLb*spillBrightness-spillBottom.BLbrightness
        errBR = bBRb*spillBrightness-spillBottom.BRbrightness
        errTotBottom = (errTL+errTR+errBL+errBR)/4

        errTL = bTLr*spillBrightness-spillRight.TLbrightness
        errTR = bTRr*spillBrightness-spillRight.TRbrightness
        errBL = bBLr*spillBrightness-spillRight.BLbrightness
        errBR = bBRr*spillBrightness-spillRight.BRbrightness
        errTotRight = (errTL+errTR+errBL+errBR)/4

        errTL = bTLbr*spillBrightness-spillBottomRight.TLbrightness
        errTR = bTRbr*spillBrightness-spillBottomRight.TRbrightness
        errBL = bBLbr*spillBrightness-spillBottomRight.BLbrightness
        errBR = bBRbr*spillBrightness-spillBottomRight.BRbrightness
        errTotBottomRight = (errTL+errTR+errBL+errBR)/4

        if considerSpill
          # combine spill with primary pixel weight
          errTot = Math.abs(errTot) + Math.abs(errTotBottom)*spillRatioBottom + Math.abs(errTotRight)*spillRatioRight + Math.abs(errTotBottomRight)*spillRatioBottomRight

        if bestCombo is null or Math.abs(errTot) < Math.abs(bestErr)
          bestErr = errTot
          closest = k
          bestCombo = combo

      # floyd-steinberg dithering
      # macro dithering - whole quadrants (not subpixels)
      
      if dither

        ditherAmount = document.getElementById('ditherAmount').value

        if document.getElementById('ditherFine').checked
          errTL = errTL1
          errTR = errTR1
          errBL = errBL1
          errBR = errBR1
        else
          # average the error to distribute across subpixels
          errTL=errTR=errBL=errBR=errTot1

        # distribute error to the right
        if j+1 < w
          gr[i*w + j+2] += (errTL * 7/16)*ditherAmount
          gr[i*w + j+3] += (errTR * 7/16)*ditherAmount
          gr[(i+1)*w + j+2] += (errBL * 7/16)*ditherAmount
          gr[(i+1)*w + j+3] += (errBR * 7/16)*ditherAmount
        # distribute error to the bottom left
        if i+1 < h and j-1 > 0
          gr[(i+2)*w + j-2] += (errTL * 3/16)*ditherAmount
          gr[(i+2)*w + j-1] += (errTR * 3/16)*ditherAmount
          gr[(i+3)*w + j-2] += (errBL * 3/16)*ditherAmount
          gr[(i+3)*w + j-1] += (errBR * 3/16)*ditherAmount
        # distribute error to the bottom
        if i+1 < h
          gr[(i+2)*w + j] += (errTL * 5/16)*ditherAmount
          gr[(i+2)*w + j+1] += (errTR * 5/16)*ditherAmount
          gr[(i+3)*w + j] += (errBL * 5/16)*ditherAmount
          gr[(i+3)*w + j+1] += (errBR * 5/16)*ditherAmount
        # distribute error to the bottom right
        if i+1 < h and j+1 < w
          gr[(i+2)*w + j+2] += (errTL * 1/16)*ditherAmount
          gr[(i+2)*w + j+3] += (errTR * 1/16)*ditherAmount
          gr[(i+3)*w + j+2] += (errBL * 1/16)*ditherAmount
          gr[(i+3)*w + j+3] += (errBR * 1/16)*ditherAmount
        
        
      row.push closest
      comboRow.push bestCombo
    combosArray.push row
    bestCombos.push comboRow

  drawCharImage()
  drawLayers()

drawCharImage = ->
  
  
  inCanvas = document.getElementById('inputImage')
  outCanvas = document.getElementById('outputImage')
  # the input image will have been resized to (cols,rows)*2*2 (quadrant,subpixel)
  outCanvas.width = charset.qWidth * inCanvas.width / 2
  outCanvas.height = charset.qHeight * inCanvas.height / 2
  ctx = outCanvas.getContext("2d")
  ctx.clearRect(0, 0, outCanvas.width, outCanvas.height)
  for i in [0...bestCombos.length]
    for j in [0...bestCombos[0].length]
      combo = bestCombos[i][j]
      # print combo image
     # TODO print actual characters
      ctx.putImageData(combo.image,j*charset.qWidth,i*charset.qHeight)


drawLayers = ->

  console.log combosArray

  layer1 = document.getElementById('layer1')
  layer2 = document.getElementById('layer2')
  layer3 = document.getElementById('layer3')
  layer4 = document.getElementById('layer4')

  outCanvas = outCanvas1 = layer1
  # each character is the size of 4 quadrants
  outCanvas1.width = charset.qWidth * combosArray[0].length
  outCanvas1.height = charset.qHeight * combosArray.length
  ctx1 = outCanvas1.getContext("2d")
  ctx1.clearRect(0, 0, outCanvas.width, outCanvas.height)

  outCanvas2 = layer2
  # each character is the size of 4 quadrants
  outCanvas2.width = charset.qWidth * combosArray[0].length
  outCanvas2.height = charset.qHeight * combosArray.length
  ctx2 = outCanvas2.getContext("2d")
  ctx2.clearRect(0, 0, outCanvas.width, outCanvas.height)

  outCanvas3 = layer3
  # each character is the size of 4 quadrants
  outCanvas3.width = charset.qWidth * combosArray[0].length
  outCanvas3.height = charset.qHeight * combosArray.length
  ctx3 = outCanvas3.getContext("2d")
  ctx3.clearRect(0, 0, outCanvas.width, outCanvas.height)

  outCanvas4 = layer4
  # each character is the size of 4 quadrants
  outCanvas4.width = charset.qWidth * combosArray[0].length
  outCanvas4.height = charset.qHeight * combosArray.length
  ctx4 = outCanvas4.getContext("2d")
  ctx4.clearRect(0, 0, outCanvas.width, outCanvas.height)

  for i in [0...combosArray.length-1] by 2
    for j in [0...combosArray[0].length-1] by 2

      charLayer1 = charset.selected[ combosArray[i][j] ]
      charLayer2 = charset.selected[ combosArray[i][j+1] ]
      charLayer3 = charset.selected[ combosArray[i+1][j] ]
      charLayer4 = charset.selected[ combosArray[i+1][j+1] ]


      ctx1.putImageData(charLayer1.TL,j*charset.qWidth,i*charset.qHeight)
      ctx1.putImageData(charLayer1.TR,j*charset.qWidth+charset.qWidth,i*charset.qHeight)
      ctx1.putImageData(charLayer1.BL,j*charset.qWidth,i*charset.qHeight+charset.qHeight)
      ctx1.putImageData(charLayer1.BR,j*charset.qWidth+charset.qWidth,i*charset.qHeight+charset.qHeight)
      
      ctx2.putImageData(charLayer2.TL,j*charset.qWidth,i*charset.qHeight)
      ctx2.putImageData(charLayer2.TR,j*charset.qWidth+charset.qWidth,i*charset.qHeight)
      ctx2.putImageData(charLayer2.BL,j*charset.qWidth,i*charset.qHeight+charset.qHeight)
      ctx2.putImageData(charLayer2.BR,j*charset.qWidth+charset.qWidth,i*charset.qHeight+charset.qHeight)
      
      ctx3.putImageData(charLayer3.TL,j*charset.qWidth,i*charset.qHeight)
      ctx3.putImageData(charLayer3.TR,j*charset.qWidth+charset.qWidth,i*charset.qHeight)
      ctx3.putImageData(charLayer3.BL,j*charset.qWidth,i*charset.qHeight+charset.qHeight)
      ctx3.putImageData(charLayer3.BR,j*charset.qWidth+charset.qWidth,i*charset.qHeight+charset.qHeight)
      
      ctx4.putImageData(charLayer4.TL,j*charset.qWidth,i*charset.qHeight)
      ctx4.putImageData(charLayer4.TR,j*charset.qWidth+charset.qWidth,i*charset.qHeight)
      ctx4.putImageData(charLayer4.BL,j*charset.qWidth,i*charset.qHeight+charset.qHeight)
      ctx4.putImageData(charLayer4.BR,j*charset.qWidth+charset.qWidth,i*charset.qHeight+charset.qHeight)
      


greyscale = (canvas) ->
  greyscaleMethod = $('#bw').val()
  customR = $('#customR').val()
  customG = $('#customG').val()
  customB = $('#customB').val()
  greyArray = []
  cvs = canvas.getContext('2d')
  imgData = cvs.getImageData(0,0,canvas.width,canvas.height)
  imgData = imgData.data
  for p in [0...imgData.length] by 4
    l = 0
    if greyscaleMethod is 'ccir'
      [r,g,b] = [0.2989, 0.5870, 0.1140]
    else if greyscaleMethod is 'cie'
      [r,g,b] = [0.2126, 0.7152, 0.0722]
    else if greyscaleMethod is 'flat'
      [r,g,b] = [0.3333, 0.3333, 0.3333]
    else if greyscaleMethod is 'red'
      [r,g,b] = [1, 0, 0]
    else if greyscaleMethod is 'green'
      [r,g,b] = [0, 1, 0]
    else if greyscaleMethod is 'blue'
      [r,g,b] = [0, 0, 1]
    l += imgData[p] * r * customR * imgData[p+3] / 255 #Red
    l += imgData[p+1] * g * customG * imgData[p+3] / 255 #Green
    l += imgData[p+2] * b * customB * imgData[p+3] / 255 #Blue

    # invert pixel values
    l = 255-l

    greyArray.push(l)

  ###
  # normalize image weights
  maxBright = _.max(greyArray)
  minBright = _.min(greyArray)
  for pixel in greyArray
    pixel = 255 - (255*(pixel-minBright))/(maxBright-minBright)
  ###

  return greyArray

theImage = ''

inputImage =
  dropImage: (source) ->
    render = (src) ->
      image = new Image();
      image.onload = ->
        rowLength = $('#row_length').val()
        canvas = document.getElementById('inputImage')
        ctx = canvas.getContext("2d")
        aspectRatio = image.height/image.width
        charAspect = charset.chars[0].TL.width/charset.chars[0].TL.height
        # multiplier of 4 accounts for quadrant splitting and subpixels
        canvas.width = rowLength*4
        canvas.height = rowLength*aspectRatio*4*charAspect
        ctx.drawImage(image, 0, 0, canvas.width, canvas.height)
        # run the comparison
        imgToText()
      image.src = src

    loadImage = (src) ->
      # Prevent any non-image file type from being read.
      if !src.type.match(/image.*/)
        console.log("The dropped file is not an image: ", src.type)
        return

      # Create our FileReader and run the results through the render function.
      reader = new FileReader()
      reader.onload = (e) ->
        render e.target.result
      reader.readAsDataURL(src)

    loadImage(source)
    theImage = source


# handle UI events

chopCharset = ->
  charset.getSettings()
  charset.chopPreview()
  charset.chopCharset()
  charset.drawCharSelect()
  charset.drawCharQuadrants()

$('#chopCharset').click ->
  chopCharset()


$('#genCombos').click ->
  charset.genCombos()

target = document.getElementById('charset-target')
target.addEventListener 'dragover', ((e) ->
  e.preventDefault()
  return
), true
target.addEventListener 'drop', ((e) ->
  e.preventDefault()
  charset.dropImage e.dataTransfer.files[0]
  return
), true

target = document.getElementById('image-target')
target.addEventListener 'dragover', ((e) ->
  e.preventDefault()
  return
), true
target.addEventListener 'drop', ((e) ->
  e.preventDefault()
  inputImage.dropImage e.dataTransfer.files[0]
  return
), true

$('#row_length').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#customR').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#customG').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#customB').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#bw').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#dithering').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#ditherFine').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#ditherAmount').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#considerSpill').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#spillRatio').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#spillRatioRight').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#spillRatioBottom').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#spillRatioBottomRight').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$('#spillBrightness').change ->
  if theImage != ''
    inputImage.dropImage(theImage)

$(document).ready ->

  document.getElementById("outputImage").setAttribute('crossOrigin', 'anonymous')

  downloadCanvas = (link, canvasId, filename) ->
      link.href = document.getElementById(canvasId).toDataURL()
      link.download = filename

  document.getElementById('download').addEventListener('click', ->
      downloadCanvas(this, 'outputImage', 'kword_mockup.png')
  , false)

  document.getElementById("layer1").setAttribute('crossOrigin', 'anonymous')

  document.getElementById('download_layer_1').addEventListener('click', ->
      downloadCanvas(this, 'layer1', 'kword_layer1_TopLeft.png')
  , false)

  document.getElementById("layer2").setAttribute('crossOrigin', 'anonymous')

  document.getElementById('download_layer_2').addEventListener('click', ->
      downloadCanvas(this, 'layer2', 'kword_layer2_TopRight.png')
  , false)

  document.getElementById("layer3").setAttribute('crossOrigin', 'anonymous')

  document.getElementById('download_layer_3').addEventListener('click', ->
      downloadCanvas(this, 'layer3', 'kword_layer3_BottomLeft.png')
  , false)

  document.getElementById("layer4").setAttribute('crossOrigin', 'anonymous')

  document.getElementById('download_layer_4').addEventListener('click', ->
      downloadCanvas(this, 'layer4', 'kword_layer4_BottomRight.png')
  , false)


# user interface buttons

$('#tabs button').click ->
  $('#tabs button.selected').removeClass('selected')
  $(this).addClass('selected')
  id = $(this).attr('id')
  $('#viewport div.show').removeClass('show')
  $('#view_'+id).addClass('show')
  