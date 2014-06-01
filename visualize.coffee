fftw3 = require './build/Release/fftw3.node'
fs = require 'fs'
stream = require 'stream'
pcm = require './pcm'
_ = require 'underscore'
{Complex} = require './complex'

google.load 'visualization', '1'

google.setOnLoadCallback ->
  getPowerTable = (options) ->
    options = _.extend {
      windowSize: 8000
      stepSize: 1000
      success: ->
    }, options
    
    unless options.stream?
      throw new Error 'Missing "stream" option.'

    powerTable = []
    
    plan = new fftw3.Plan options.windowSize, true
    buffer = []
    timeSinceLastFrame = 0
    powerTableIndex = 0

    pending = 0

    options.stream.on 'data', (number) ->
      buffer.push number

      if buffer.length > options.windowSize
        buffer.shift()

      timeSinceLastFrame += 1

      if timeSinceLastFrame >= options.stepSize and buffer.length is options.windowSize
        timeSinceLastFrame = 0
        do (powerTableIndex) ->
          pending++
          fftBuffer = (new Complex(el, 0) for el in buffer)

          data = Complex.inflate plan.execute Complex.flatten(fftBuffer)

          powerSeries = (el.mag() for el, i in data)

          console.log powerTableIndex

          powerTable[powerTableIndex] = powerSeries

          pending--

        powerTableIndex += 1

    options.stream.on 'end', checkAgain = ->
      console.log 'GOT DONE', pending

      if pending is 0
        options.success powerTable
      else
        setTimeout checkAgain, 1

  input = fs.createReadStream 'audio.wav'

  reader = new pcm.Reader(); input.pipe reader

  WINDOW = 1000

  getPowerTable
    stream: reader
    windowSize: WINDOW
    stepSize: WINDOW
    success: (powers) ->
      # We've obtained the STFT frames for the audio. Now set things up properly:
      data = new google.visualization.DataTable()

      for i in [1..(Math.floor(WINDOW / 2) + 1)]
        data.addColumn 'number', 'col' + i

      data.addRows powers.length

      for frame, i in powers
        for power, j in frame[..Math.floor(frame.length / 2)]
          data.setValue i, j, power / (WINDOW * 1000)
      
      surfacePlot = new greg.ross.visualisation.SurfacePlot document.getElementById 'surfacePlotDiv'

      surfacePlot.draw data, {
        xPos: 50
        yPos: 0
        width: 500
        height: 500
        colourGradient: [
          {red: 0, green: 0, blue: 255}
          {red: 0, green: 255, blue: 255}
          {red: 0, green: 255, blue: 0}
          {red: 255, green: 255, blue: 0}
          {red: 255, green:0, blue: 0}
        ]
        fillPolygons: true
        xTitle: 'X'
        yTitle: 'Y'
        zTitle: 'Z'
        restrictXRotation: false
      }
