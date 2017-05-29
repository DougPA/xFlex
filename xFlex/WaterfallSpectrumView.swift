//
//  WaterfallSpectrumView.swift
//  xFlex v0.2
//
//  Created by Douglas Adams on 10/6/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

// ------------------------------------------------------------------------------
// MARK: - Waterfall View
// ------------------------------------------------------------------------------

final class WaterfallSpectrumView : NSOpenGLView, WaterfallStreamHandler {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    override var flipped: Bool { return true }
    
    weak var panafall: Panafall! { didSet { Swift.print("panafall, \(panafall)")}}                                   // Panafall associated with this Waterfall
    weak var waterfall: Waterfall! {                                // Waterfall object
        didSet {
            
            Swift.print("waterfall, \(waterfall)")
            
//            waterfall.delegate = self
            
            // create a Gradient
            _waterfallGradient = WaterfallGradient()
            
            // force an update during drawing
            _updateGradient = true
            _updateLevels = true
            
            // add Waterfall property observers (for changes affecting the Gradient)
            for keyPath in self._waterfallKeyPaths {
                
                waterfall.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
            }
        }
    }
    var updateSize = false                                          // flag to indicate size of SplitView has changed
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let kModule = "Waterfall"                               // Module Name reported in log messages
    private let _p = ViewPreferences.sharedInstance                 // Shared View Preferences
    private let _log = Log.sharedInstance                           // Shared log
    
    // keyPath property observations
    private let _waterfallKeyPaths =  ["autoBlackEnabled", "blackLevel", "colorGain", "gradientIndex"]

    // OpenGL
    private var _tools = OpenGLTools()                              // OpenGL support class
    private var _vaoHandle: GLuint = 0                              // Vertex Array Object handle
    private var _verticesVboHandle: GLuint = 0                      // Vertex Buffer Object handle (vertices)
    private var _texCoordsVboHandle: GLuint = 0                     // Vertex Buffer Object handle (Texture coordinates)
    private var _tboHandle: GLuint = 0                              // Texture Buffer Object handle
    private let _verticesLocation: GLuint = 0                       // fixed - in location (vertices)
    private let _texCoordsLocation: GLuint = 1                      // fixed - in location ( Texture coordinates)
    private var _texValuesLocation: GLint = 0                       // variable - texValues uniform location
    
    private let _glAttributes: [NSOpenGLPixelFormatAttribute] =     // Pixel format attributes
    [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize), UInt32(32),
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(0)
    ]

    private var _shaders =                                          // array of Shader structs
    [
            ShaderStruct(name: "Waterfall", type: .Vertex),
            ShaderStruct(name: "Waterfall", type: .Fragment)
    ]

    private var vertices: [GLfloat] =                               // vertices & tex coords
    //    x     y     s      t
    [
         1.0,  1.0,  0.41,  1.0,                                     // 16 bytes per vertex
         1.0, -1.0,  0.41,  0.0,
        -1.0,  1.0,  0.0,   1.0,
        -1.0, -1.0,  0.0,   0.0
    ]
    
    private var _clearColor: [GLfloat] {                            // Waterfall background color
        return
            [
                GLfloat(_p.spectrumBackground.redComponent),
                GLfloat(_p.spectrumBackground.greenComponent),
                GLfloat(_p.spectrumBackground.blueComponent),
                GLfloat(_p.spectrumBackground.alphaComponent)
            ] }

    private var _previousNumberOfBins: Int = 0                      // number of bins on last draw
    private var _previousPanafallBandwidth: CGFloat = 0             // Panafall Bandwidth on last draw
    private var _previousBinBandwidth: CGFloat = 0                  // Bin Bandwidth on last draw
    private var _previousFirstBinFreq: CGFloat = 0                  // First Bin Freq on last draw
    private var _previousLineDuration: CGFloat = 0                  // Line Duration on last draw
    private var _previousSize = NSSize(width: 0, height: 0)         // view size on last draw
    private var _deltaHeight: CGFloat = 0                           // reshape change in height
    
    private var _prepared = false
        {                                 // whether prepareOpenGL has completed
        didSet { Swift.print("prepared")
            if _prepared { waterfall.delegate = self }
        } }     // ready to process Waterfall frames
    
    private var _waterfallGradient: WaterfallGradient?              // Gradient class

    private var _updateGradient = false                             // set when Gradient needs to be updated
    private var _updateLevels = false                               // set when Levels need to be updated
    
//    private var _timeLegendView: TimeLegendView?
    
    private var _line = [GLuint]()
    private var _currentLine: GLint = 0
    private var _yOffset: GLfloat = 0
    private var _stepValue: GLfloat = 0
    private var _adjust: GLfloat = 0

    private let kWidthInPoints: GLint = 4096
    private let kHeightInPoints: GLint = 1024
    private var _texture = [UInt8]()
    
    private var _startFrequency: CGFloat { return panafall.center - panafall.bandwidth/2 }
    private var _endFrequency: CGFloat { return panafall.center + panafall.bandwidth/2 }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // setup OpenGL
        pixelFormat = NSOpenGLPixelFormat(attributes: _glAttributes)
        openGLContext = NSOpenGLContext(format: pixelFormat!, shareContext: nil)
        
        //  Set the context's swap interval parameter to 60Hz (i.e. 1 frame per swap)
        self.openGLContext?.setValues([1], forParameter: .GLCPSwapInterval)
        
        // obtain a reference to the Time Legend view
//        _timeLegendView = superview!.subviews[1] as? TimeLegendView
    }
    //
    // Respond to changes in observed KeyPaths
    //      may be called on any thread
    //
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
            switch keyPath! {
                
            case "autoBlackEnabled", "blackLevel", "colorGain":
                
                    // something changed, recalculate levels
                    self._updateLevels = true
                
            case "gradientIndex":
                
                    // the Gradient selection has changed
                    self._updateGradient = true
                
            default:
                break
            }
    }

    deinit {
        
        // free the OpenGL components
        glDeleteVertexArrays(1, &_vaoHandle)
        glDeleteBuffers(1, &_verticesVboHandle)
        glDeleteBuffers(1, &_texCoordsVboHandle)
        glDeleteBuffers(1, &_tboHandle)
        glDeleteProgram(_shaders[0].program!)

        // remove Waterfall property observers
        for keyPath in _waterfallKeyPaths {
            
            waterfall.removeObserver(self, forKeyPath: keyPath, context: nil)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden OpenGL methods
    
    override func prepareOpenGL() {
//        super.prepareOpenGL()
        
        // set a "Clear" color
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        // create a ProgramID, Compile & Link the Shaders
        if !_tools.loadShaders(&_shaders) {
            // FIXME: do something if there is an error
            NSLog("Error - \(_shaders[0].error!)")
        }
        
        // create & bind a TBO
        glGenTextures(1, &_tboHandle)
        glBindTexture(GLenum(GL_TEXTURE_2D), _tboHandle)
        
        // setup the texture
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT)
        
        _texture = [UInt8](count: Int(kWidthInPoints * 4 * kHeightInPoints), repeatedValue: 0x88)
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, kWidthInPoints, kHeightInPoints, 0, GLenum(GL_RGBA),
                     GLenum(GL_UNSIGNED_BYTE), _texture)

        // setup a VBO for the vertices & tex coordinates
        glGenBuffers(1, &_verticesVboHandle)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _verticesVboHandle)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(vertices.count * sizeof(GLfloat)), vertices, GLenum(GL_DYNAMIC_DRAW))
        
        // create & bind a VAO
        glGenVertexArrays(1, &_vaoHandle)
        glBindVertexArray(_vaoHandle)
        
        // setup & enable the vertex attribute array for the Vertices
        glVertexAttribPointer(_verticesLocation, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, UnsafePointer<GLfloat>(bitPattern: 0))
        glEnableVertexAttribArray(_verticesLocation)
        
        // setup & enable the vertex attribute array for the Vertices
        glVertexAttribPointer(_texCoordsLocation, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, UnsafePointer<GLfloat>(bitPattern: 8))
        glEnableVertexAttribArray(_texCoordsLocation)
        
        // locate & populate the Texture sampler
        _texValuesLocation = glGetUniformLocation(_shaders[0].program!, "texValues")
        glUniform1i(_texValuesLocation, GL_TEXTURE0)
        
        // put the program into effect
        glUseProgram(_shaders[0].program!)
        
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
        
        _line = [GLuint](count: Int(kWidthInPoints), repeatedValue: 0xFF888888)

        // prepare is completed
        _prepared = true
        
//        var mMajor = [GLint](count:1, repeatedValue: 0)
//        var mMinor = [GLint](count:1, repeatedValue: 0)
//        glGetIntegerv(GLenum(GL_MAJOR_VERSION), &mMajor)
//        glGetIntegerv(GLenum(GL_MINOR_VERSION), &mMinor)
//        
//        Swift.print("Version = \(mMajor[0]).\(mMinor[0])")
    }
    
    override func reshape() {
//        super.reshape()
        
        Swift.print("reshape")
    }

    // ----------------------------------------------------------------------------
    // MARK: - WaterfallStreamHandler protocol methods
    //
    //  dataFrame Layout: (see xFlexAPI WaterfallFrame)
    //
    //  public var firstBinFreq: CGFloat                        // Frequency of first Bin in Hz
    //  public var binBandwidth: CGFloat                        // Bandwidth of a single bin in Hz
    //  public var lineDuration: CGFloat                        // Duration of this line in ms
    //  public var lineHeight: Int                              // Height of frame in pixels
    //  public var autoBlackLevel: UInt32                       // Auto black level
    //  public var numberOfBins: Int                            // Number of bins
    //  public var bins: [UInt16]                               // Array of bin values
    //
    
    //
    // Process the UDP Stream Data for the Waterfall
    //      called by Waterfall, executes on the waterfallQ Queue
    //
    func waterfallStreamHandler(dataFrame: WaterfallFrame ) {
        
        // make the context active and lock it
        openGLContext!.makeCurrentContext()
        CGLLockContext(openGLContext!.CGLContextObj)
        
        
        // update the gradient (if needed)
        if _updateGradient {
            
            // get the name of the selected Gradient
            let selectedName = _waterfallGradient!.gradientNames[waterfall.gradientIndex]
            
            // setup the gradient
            _waterfallGradient!.loadGradient(selectedName)
            _updateGradient = false
        }
        // update the levels (if needed)
        if _updateLevels {
            
            _waterfallGradient?.calcLevels(waterfall.autoBlackEnabled, autoBlackLevel: dataFrame.autoBlackLevel, blackLevel: waterfall.blackLevel, colorGain: waterfall.colorGain)
            _updateLevels = false
        }

        // Populate the current "line"
        let binsPtr = UnsafeMutablePointer<UInt16>(dataFrame.bins)
        
        let startBinNumber = Int((_startFrequency - dataFrame.firstBinFreq) / dataFrame.binBandwidth)
        let endBinNumber = Int((_endFrequency - dataFrame.firstBinFreq) / dataFrame.binBandwidth)
        let binCount = endBinNumber - startBinNumber
        let percent = GLfloat(binCount) / GLfloat(kWidthInPoints)
        
//        Swift.print("start = \(startBinNumber), end = \(endBinNumber), percent = \(percent)")
        
        var i = 0
        for binNumber in startBinNumber...endBinNumber {
            
            _line[i] = GLuint(_waterfallGradient!.value(binsPtr.advancedBy(binNumber).memory))
            i += 1
       }

//        Swift.print("bins = \(dataFrame.numberOfBins)")
        
        //        Swift.print("i - \(intensity), be = \(autoBlackEnabled)), b = \(blackLevel), cg = \(colorGain)")
        
        // update the current line in the Texture
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, _currentLine, kWidthInPoints, 1, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), _line)
        
        // increment the line number
        _currentLine = (_currentLine + 1) % kHeightInPoints
        
        // calculate and set the variable portion of the Texture coordinates
        _yOffset = GLfloat(_currentLine) / GLfloat(kHeightInPoints - 1)
        _stepValue = 1.0 / GLfloat(kHeightInPoints - 1)
        _adjust = (GLfloat(kHeightInPoints) - GLfloat(frame.height)) / GLfloat(kHeightInPoints)
        
        vertices[3] = _yOffset + 1 - _stepValue
        vertices[7] = _yOffset + _adjust
        vertices[11] = _yOffset + 1 - _stepValue
        vertices[15] = _yOffset + _adjust
        
        vertices[2] = percent
        vertices[6] = percent
        
//        vertices[1] = _top
//        vertices[9] = _top
        
        // bind the vertices
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _verticesVboHandle)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(vertices.count * sizeof(GLfloat)), vertices, GLenum(GL_DYNAMIC_DRAW))
        
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height))
        
        // clear & draw
        glClear(GLenum(GL_COLOR_BUFFER_BIT))
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), GLint(0), GLsizei(4))
        
        // swap the buffer and unlock the context
        CGLFlushDrawable(openGLContext!.CGLContextObj)
        CGLUnlockContext(openGLContext!.CGLContextObj)
        
        _previousNumberOfBins = dataFrame.numberOfBins
    }
    
//    override func update() {
//        super.update()
//        
//        Swift.print("update")
//    }
//    
//    override func viewWillStartLiveResize() {
//        Swift.print("viewWillStartLiveResize")
//    }
//
//    override func viewDidEndLiveResize() {
//        Swift.print("viewDidEndLiveResize")
//    }
//    
//    override var preservesContentDuringLiveResize: Bool {
//        return true
//    }
}