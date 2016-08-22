charset =

	previewCanvas: document.getElementById('charsetPreview') # onscreen display of charset (keystoned and cropped)
	overlayCanvas: document.getElementById('charsetOverlay') # onscreen display of chopping grid / selected chars
	workingCanvas: document.createElement('canvas') # in memory canvas for hi-res operations

	settings: # defined by user input from onscreen
		keystones: [ [],[],[],[] ] # four [x,y] positions indicating centers of 4 keystone points on charset preview
		gridSize: [20,20] # [x,y] number of columns,rows in between (not including) keystones
		offset: [] # [x,y] multiples of character size to offset right and down, compensates for keystone centers
		start: [] # [x,y] position on grid of the top left character in the desired charset, in [column,row] (start from 0)
		end: [] # [x,y] position on grid of the bottom right character in the desired charset, in [column,row] (start from 0)

	chars: [] # array of individual objects

	getSettings: ->
		formValues = {}

		for formField in ['rows','cols','rowStart','rowEnd','colStart','colEnd','offsetX','offsetY']
			formValues[formField] = document.getElementById(formField).value

		charset.settings.gridSize = [(formValues.cols/1)+1,(formValues.rows/1)+1]
		charset.settings.offset = [formValues.offsetX,formValues.offsetY]
		charset.settings.start = [formValues.colStart,formValues.rowStart]
		charset.settings.end = [formValues.colEnd,formValues.rowEnd]

	# TODO: skipping keystoning for now
	chopPreview: -> # previews chop grid settings on an overlay canvas
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
			console.log ' start = ' + start
			console.log ' end = ' + end
			ctx.clearRect(start[0],start[1],end[0]-start[0]+offsetX,end[1]-start[1]+offsetY)

		lightboxSelection()

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
		charset.chars = []
		ctx = charset.workingCanvas.getContext('2d')
		charWidth = charset.workingCanvas.width / charset.settings.gridSize[0]
		charHeight = charset.workingCanvas.height / charset.settings.gridSize[1]
		offsetX = charWidth * charset.settings.offset[0]
		offsetY = charHeight * charset.settings.offset[1]
		start = [charset.settings.start[0]*charWidth+offsetX,charset.settings.start[1]*charHeight+offsetY]
		numRows = (charset.settings.end[1] - charset.settings.start[1])
		numCols = (charset.settings.end[0] - charset.settings.start[0])

		i = 0
		for row in [0..numRows]
			for col in [0..numCols]
				startChar = [start[0]+charWidth*col,start[1]+charHeight*row]
				imgData = ctx.getImageData Math.round(startChar[0]),Math.round(startChar[1]),Math.round(charWidth),Math.round(charHeight)
				weight = 0 # quick weighing
				for p in [0...imgData.data.length] by 4
					weight += imgData.data[p]
					weight += imgData.data[p+1]
					weight += imgData.data[p+2]
				char =
					imgData: imgData
					weight: weight
					selected: true
					index: i
				charset.chars.push char
				i++

		charset.chars = _(charset.chars).sortBy('weight')
		maxWeight = _.max(charset.chars,(w) -> w.weight).weight
		minWeight = _.min(charset.chars,(w) -> w.weight).weight
		for char in charset.chars
			char.brightness = 255 - (255*(char.weight-minWeight))/(maxWeight-minWeight)

	drawCharSelect: ->
		$('#viewSelect').empty()
		for char in charset.chars
			# create canvas
			newCanvasHtml = '<canvas id="char'+char.index+'" width="'+char.imgData.width+'" height="'+char.imgData.height+'"></canvas>'
			$('#viewSelect').append newCanvasHtml
			cvs = document.getElementById('char'+char.index)
			ctx = cvs.getContext("2d")
			ctx.putImageData(char.imgData,0,0)
			
			makeClickHandler = (char) ->
				$('#char'+char.index).click ->
					cvs = document.getElementById('char'+char.index)
					ctx = cvs.getContext("2d")
					char.selected = !char.selected
					# redraw greyed out if unselected
					ctx.clearRect(0, 0, char.imgData.width, char.imgData.height)
					if ! char.selected
						ctx.putImageData(char.imgData,0,0)
						ctx.fillStyle = "rgba(0,0,0,0.5)"
						ctx.fillRect(0, 0, char.imgData.width, char.imgData.height)
					else
						ctx.putImageData(char.imgData,0,0)

			makeClickHandler(char)

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
		  #	Prevent any non-image file type from being read.
		  if !src.type.match(/image.*/)
		    console.log 'The dropped file is not an image: ', src.type
		    return
		  #	Create our FileReader and run the results through the render function.
		  reader = new FileReader

		  reader.onload = (e) ->
		    render e.target.result
		    renderWorking e.target.result
		    return

		  reader.readAsDataURL src
		  return

		loadImage(source)

# handle UI events

$('#chopCharset').click ->
	console.log 'chop character set'
	charset.getSettings()
	charset.chopPreview()
	charset.chopCharset()
	charset.drawCharSelect()

target = document.getElementById('drop-target')
target.addEventListener 'dragover', ((e) ->
  e.preventDefault()
  return
), true
target.addEventListener 'drop', ((e) ->
  e.preventDefault()
  charset.dropImage e.dataTransfer.files[0]
  return
), true