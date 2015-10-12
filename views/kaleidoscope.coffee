class Kaleidoscope

  HALF_PI: Math.PI / 2
  TWO_PI: Math.PI * 2

  viewportHeight: window.innerHeight
  viewportWidth: window.innerWidth * 2

  constructor: ( @options = {} ) ->

    @defaults =
      offsetRotation: 0.0
      offsetScale: 1.0
      offsetX: 0.0
      offsetY: 0.0
      radius: Math.max(@viewportWidth / 3, @viewportHeight)
      slices: 28
      zoom: 0.3

    @[ key ] = val for key, val of @defaults
    @[ key ] = val for key, val of @options

    @domElement ?= document.createElement 'canvas'
    @context ?= @domElement.getContext '2d'
    @image ?= document.createElement 'img'

  draw: ->

    @domElement.width = @viewportWidth * 2
    @domElement.height = @viewportHeight * 2
    @context.fillStyle = @context.createPattern @image, 'repeat'

    scale = @zoom * ( @radius / Math.min @image.width, @image.height )
    step = @TWO_PI / @slices
    cx = @image.width / 2

    for index in [ 0..@slices ]

      @context.save()
      @context.translate @radius, @radius
      @context.rotate index * step

      @context.beginPath()
      @context.moveTo -0.5, -0.5
      @context.arc 0, 0, @radius, step * -0.51, step * 0.51
      @context.lineTo 0.5, 0.5
      @context.closePath()

      @context.rotate @HALF_PI
      #@context.scale scale, scale
      @context.scale [-1,1][index % 2], 1
      @context.translate @offsetX - cx, @offsetY
      @context.rotate @offsetRotation
      @context.scale @offsetScale, @offsetScale

      @context.fill()
      @context.restore()

# Init kaleidoscope
imagesPath = 'https://imgur.com/'
presetImages = [
  'h0q4JBE.jpg', 'Pnl04ZU.gif',
  'z5tr1f7.gif', 'ogVGnla.jpg',
  'lnN2YQo.gif', 'O2xSkq7.jpg'
]

image = new Image
image.onload = => do kaleidoscope.draw
#image.src = imagesPath + presetImages[Math.round(Math.random()*4)]
image.src = imagesPath + presetImages[0]

kaleidoscope = new Kaleidoscope
  image: image
  slices: 28
  domElement: document.getElementById 'kaleidoscope'

kaleidoscope.domElement.style.position = 'absolute'
kaleidoscope.domElement.style.marginLeft = -kaleidoscope.radius + 'px'
kaleidoscope.domElement.style.marginTop = -kaleidoscope.radius + 'px'
kaleidoscope.domElement.style.left = '50%'
kaleidoscope.domElement.style.top = '50%'

tx = kaleidoscope.offsetX
ty = kaleidoscope.offsetY
tr = kaleidoscope.offsetRotation


options =
  interactive: no
  animate: yes
  reverse: no
  cycleImages: yes
  cycleOffset: yes
  ease: 1.0
  animationSpeed: 1.0

do startAnimation = =>

  if options.animate
    if options.reverse
      ty += options.animationSpeed
      tx -= options.animationSpeed
    else
      ty -= options.animationSpeed
      tx += options.animationSpeed

  setTimeout startAnimation, 1000/60

do update = =>

  delta = tr - kaleidoscope.offsetRotation
  theta = Math.atan2( Math.sin( delta ), Math.cos( delta ) )

  kaleidoscope.offsetX += ( tx - kaleidoscope.offsetX ) * options.ease
  kaleidoscope.offsetY += ( ty - kaleidoscope.offsetY ) * options.ease
  kaleidoscope.offsetRotation += ( theta - kaleidoscope.offsetRotation ) * options.ease

  do kaleidoscope.draw

  setTimeout update, 1000/60

sameImageCycles = 1

do cyclePos = =>
  if options.cycleImages
    image.src = imagesPath + presetImages[Math.round(Math.random()*4)]

  setTimeout cyclePos, 1000 * 6

kaleidoscope.
  nextImage = =>
    currentImageFile = image.src.replace imagesPath, ""
    currentImage = presetImages.indexOf currentImageFile
    if currentImage == presetImages.length - 1
      nextImagePath = presetImages[0]
    else
      nextImagePath = presetImages[currentImage + 1]
    kaleidoscope.image.src = imagesPath + nextImagePath
