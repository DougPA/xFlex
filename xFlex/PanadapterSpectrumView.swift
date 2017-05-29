//
//  PanadapterSpectrumView.swift
//  xFlex
//
//  Created by Douglas Adams on 11/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

final class PanadapterSpectrumView : NSOpenGLView, PanadapterStreamHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var panafall: Panafall! {
        didSet {
            
            // tell the Radio (hardware) the actual dimensions
            panafall.panDimensions = CGSize(width: frame.width, height: frame.height)
            
            // set the OpenGL Viewport
            reshape()
            
            // make this view the delegate
            panafall.delegate = self 
        } }
    
    var isFilled = false
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let kModule = "PanadapterSpectrumView"                  // Module Name reported in log messages
    private let _p = ViewPreferences.sharedInstance                 // View Preferences
    private let _log = Log.sharedInstance                           // shared log

    // OpenGL
    private var _tools = OpenGLTools()                              // OpenGL support class
    private var _vaoHandle: GLuint = 0                              // Vertex Array Object handle
    private var _vboHandle: GLuint = 0                              // Vertex Buffer Object handles (Y)
    private var _uniformLineColor: GLint = 0                        // Uniform location for Line Color
    private var _uniformDelta: GLint = 0                            // Uniform location for x delta
    private var _yCoordinateHandle: GLuint {return _vboHandle}      // VBO handle for Ycoordinate-data
    private let _yCoordinateLocation: GLuint = 0
    private let _glAttributes: [NSOpenGLPixelFormatAttribute] =     // Pixel attributes
    [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFADoubleBuffer),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
        UInt32(0)
    ]
    private var _shaders =                                          // array of Shader structs
    [
        ShaderStruct(name: "Panadapter", type: .Vertex),
        ShaderStruct(name: "Panadapter", type: .Fragment)
    ]
    private var _lineColor: [GLfloat] {                             // Spectrum color
        return
            [
                GLfloat(_p.spectrum.redComponent),
                GLfloat(_p.spectrum.greenComponent),
                GLfloat(_p.spectrum.blueComponent),
                GLfloat(_p.spectrum.alphaComponent)
            ] }
    
    private var _clearColor: [GLfloat] {                            // Spectrum background color
        return
            [
                GLfloat(_p.spectrumBackground.redComponent),
                GLfloat(_p.spectrumBackground.greenComponent),
                GLfloat(_p.spectrumBackground.blueComponent),
                GLfloat(_p.spectrumBackground.alphaComponent)
            ] }
    private var _previousNumberOfBins: Int = 0                      // number of bins on last draw
    
    private var _prepared = false                                   // whether prepareOpenGL has completed

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // setup OpenGL
        pixelFormat = NSOpenGLPixelFormat(attributes: _glAttributes)
        openGLContext = NSOpenGLContext(format: pixelFormat!, shareContext: nil)        

        //  Set the context's swap interval parameter to swap during the vertical interval (i.e. 60 hz)
        openGLContext?.setValues([1], forParameter: .GLCPSwapInterval)
    }

    deinit {
        glDeleteVertexArrays(1, &_vaoHandle)
        glDeleteBuffers(1, &_vboHandle)
        glDeleteProgram(_shaders[0].program!)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden OpenGL methods
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        // set a "Clear" color
        glClearColor(_clearColor[0], _clearColor[1], _clearColor[2], _clearColor[3])
        
        // create & bind VBOs for xCoordinate & yCoordinate values
        glGenBuffers(1, &_vboHandle)

        // setup the yCoordinate buffer but don't transfer any data yet
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _yCoordinateHandle)
        glBufferData(GLenum(GL_ARRAY_BUFFER), Int(frame.width) * sizeof(GLfloat), nil, GLenum(GL_STREAM_DRAW))
        _previousNumberOfBins = Int(frame.width)
        
        // create & bind a VAO
        glGenVertexArrays(1, &_vaoHandle)
        glBindVertexArray(_vaoHandle)
        
        // enable and map the vertex attribute array for the yCoordinate Buffer
        glEnableVertexAttribArray(_yCoordinateLocation)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _yCoordinateHandle)
        glVertexAttribPointer(_yCoordinateLocation, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLfloat)), UnsafePointer<GLuint>(bitPattern: 0))

        //  Unbind the VAO so no further changes are made.
        glBindVertexArray(0)
        
        // Compile the Shaders, create a ProgramID, link the Shaders to the Program
        if !_tools.loadShaders(&_shaders) {
            // FIXME: do something if there is an error
            _log.entry("\(_shaders[0].error!)", level: .Fatal, source: kModule + ", OpenGL")
        }
        
        // setup the color uniform (color for the spectrum trace)
        glUseProgram(_shaders[0].program!)

        _uniformLineColor = glGetUniformLocation(_shaders[0].program!, "lineColor")
        _uniformDelta = glGetUniformLocation(_shaders[0].program!, "delta")
        
        _prepared = true
    }
    
    override func reshape() {

        // make the context active and lock it
//        openGLContext!.makeCurrentContext()
//        CGLLockContext(openGLContext!.CGLContextObj)
        
        // update the viewport
        glViewport(0, 0, GLint(self.bounds.size.width), GLint(self.bounds.size.height))
        
        // clear the view
//        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        // swap the buffer and unlock the context
//        CGLFlushDrawable(openGLContext!.CGLContextObj)
//        CGLUnlockContext(openGLContext!.CGLContextObj)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - PanadapterStreamHandler protocol methods
    //
    //  DataFrame Layout: (see xFlexAPI PanadapterFrame)
    //
    //  public var startingBinIndex: Int                    // Index of first bin
    //  public var numberOfBins: Int                        // Number of bins
    //  public var binSize: Int                             // Bin size in bytes
    //  public var frameIndex: Int                          // Frame index
    //  public var bins: [UInt16]                           // Array of bin values
    //
    
    //
    // Process the UDP Stream Data for the Panadapter
    //      called by Panafall, executes on the udpQ Queue
    //
    func panadapterStreamHandler(dataFrame: PanadapterFrame) {
        var bufferPtr: UnsafeMutablePointer<GLfloat>
        
        // calculate the spacings between values
        var delta: GLfloat = 2.0 / GLfloat(dataFrame.numberOfBins - 1)

        // make the context active and lock it
        openGLContext!.makeCurrentContext()
        CGLLockContext(openGLContext!.CGLContextObj)
        

//        Swift.print("pan")
        
        // has the number of bins changed?
        if dataFrame.numberOfBins != _previousNumberOfBins {
            
            // re-calculate the spacings between values
            delta = 2.0 / GLfloat(dataFrame.numberOfBins - 1)
           
            // select & resize the yCoordinate buffer
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), _yCoordinateHandle)
            glBufferData(GLenum(GL_ARRAY_BUFFER), dataFrame.numberOfBins * sizeof(GLfloat), nil, GLenum(GL_STREAM_DRAW))
        }
        
        // select the Y-buffer & get a pointer to it
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), _yCoordinateHandle)
        bufferPtr = UnsafeMutablePointer<GLfloat>(glMapBuffer(GLenum(GL_ARRAY_BUFFER), GLenum(GL_WRITE_ONLY)))
        
        // populate the y Coordinates
        for i in 0..<dataFrame.numberOfBins {
            
            // incoming values range from 0 to height with 0 being the max and height being the min (i.e. it's upside down)
            // normalize to range between -1 to +1 for OpenGL
            bufferPtr.advancedBy(i).memory = GLfloat(1) - (GLfloat(2) * GLfloat(dataFrame.bins[i]) / GLfloat(frame.height))
        }
        // release the buffer
        glUnmapBuffer(GLenum(GL_ARRAY_BUFFER))
        
        // clear the view
        // set a "Clear" color
        glClearColor(_clearColor[0], _clearColor[1], _clearColor[2], _clearColor[3])
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        // select the Program & bind the VAO
        glUseProgram(_shaders[0].program!)
        glBindVertexArray(_vaoHandle)
        
        // set the uniforms
        glUniform4fv(_uniformLineColor , 1, _lineColor)
        glUniform1f(_uniformDelta , delta)

        // draw the Panadapter trace
        glDrawArrays(GLenum(GL_LINE_STRIP), GLint(0), GLsizei(dataFrame.numberOfBins))
        
        //  Unbind the VAO
        glBindVertexArray(0)
        
        // swap the buffer and unlock the context
        CGLFlushDrawable(openGLContext!.CGLContextObj)
        CGLUnlockContext(openGLContext!.CGLContextObj)
        
        _previousNumberOfBins = dataFrame.numberOfBins
    }
    
}
