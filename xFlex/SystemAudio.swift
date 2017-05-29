//
//  SystemAudio.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/29/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import OpenAL
import xFlexAPI

let kOpusRingBufferPowerOfTwo = 13                          // 2^13 = 8192 Int16's
let kOpusBufferCount = 6                                    // number of buffers
let kOpusSampleRate = 24_000                                // sample rate
let kOpusFrameCount = kOpusSampleRate / 100                 // number of decoded frames
let kOpusChannelCount = 2

public final class SystemAudio : NSObject, OpusStreamHandler {

    typealias BufferDescriptor = (buffer: ALuint, index: Int)
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _player = StreamPlayer()                                    // player structure
    fileprivate var alDevice: OpaquePointer?                                    // OpenAL Device pointer
    fileprivate var alContext: OpaquePointer?                                   // OpenAL Context pointer
    fileprivate var buffers = [ALuint](repeating: 0, count: kOpusBufferCount)   // OpenAL buffer handle array
    
    fileprivate var tempBuffer = [Int16](repeating: 0, count: kOpusFrameCount * kOpusChannelCount)
    
    fileprivate let kOpusByteCount = kOpusFrameCount * kOpusChannelCount * MemoryLayout<Int16>.size

    fileprivate var _decoder: OpaquePointer!                                    // Opaque pointer to Opus Decoder
    fileprivate let _opusKeyPaths =  ["rxOn", "txOn"]                           // Opus KVO keypaths
    
    fileprivate let kModule = "SystemAudio"
    fileprivate let _log = Log.sharedInstance                                   // shared log
    fileprivate let _openAlQ = DispatchQueue(label: "xFlex.OpenAL")

    //------------------------------------------------------------------------------
    // MARK: Struct definition
    
    struct StreamPlayer {
        var sources = [ALuint](repeating: 0, count: 1)                          // OpenAL source handles
        var ringBuffer = RingBuffer(size: kOpusRingBufferPowerOfTwo)            // Ring Buffer
        var buffersProcessed = 0
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public override init() {

        // create the Opus decoder
        var opusError: Int32 = 0
        _decoder = opus_decoder_create(Int32(kOpusSampleRate), Int32(kOpusChannelCount), &opusError)
        if opusError != 0 { Swift.print("Decoder create error = \(opusError)") }
        
        // create the player
        _player = StreamPlayer()
        
        super.init()
        
        // set up OpenAL Device
        alDevice = alcOpenDevice(nil)
        checkAL("Couldn't open AL device") // default device
        
        // set up OpenAL Context
        var attrList: ALCint = 0
        alContext = alcCreateContext(alDevice, &attrList)
        checkAL("Couldn't open AL context")
        
        alcMakeContextCurrent(alContext)
        checkAL("Couldn't make AL context current")
        
        // create OpenAL buffers
        alGenBuffers(ALsizei(kOpusBufferCount), &buffers)
        checkAL("Couldn't generate buffers")
        
        // set up OpenAL source
        alGenSources(1, &_player.sources)
        checkAL("Couldn't generate sources")

        // set the gain
        alSourcef(_player.sources[0], AL_GAIN, ALfloat(AL_MAX_GAIN))
        checkAL("Couldn't set source gain")
        
        // set the initial sound position
        alSource3f(_player.sources[0], AL_POSITION, 0.0, 0.0, 0.0)
        checkAL("Couldn't set sound position")
        
        // enable the AL_EXT_SOURCE_NOTIFICATIONS & AL_EXT_STATIC_BUFFER extensions
        let _ = enableExtensions()
        
        // set the listener position
        alListener3f (AL_POSITION, 0.0, 0.0, 0.0)
        checkAL("Couldn't set listner position")
    }
    
    deinit {
        
        // cleanup
        alSourceStop(_player.sources[0])
        alDeleteSources(1, _player.sources)
        alDeleteBuffers(ALsizei(kOpusBufferCount), buffers)
        alcDestroyContext(alContext)
        alcCloseDevice(alDevice)
        
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    //
    // Process changes to observed keyPaths
    //      may arrive on any thread
    //
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        // put the response on the main queue
        DispatchQueue.main.async { [unowned self] in
            
            // the object is a reference to the Opus object
            let opus = object as! Opus
            
            switch keyPath! {
                
            case "rxEnabled":        // Opus Receive stream change
                // start/stop the Opus Audio output
                if opus.rxEnabled {
                    
//                    self._player.buffersProcessed = 0
//                    
//                    alSourcePlayv (1, self._player.sources)
//                    self.checkAL("Couldn't play")
                    
                    opus.delegate = self
                    

                    
                } else {
                    
                    opus.delegate = nil
                    
                    alSourceStopv(1, self._player.sources)
                    self.checkAL("Couldn't stop")
                }
                
            case "txEnabled":        // Opus Transmit stream change
                // FIXME: Need code
                break
                
            default:
                break
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods

    //
    //
    //
    func enableExtensions() {
//        var	bufferDataStaticProc: alBufferDataStaticProcPtr
        var sourceAddNotificationProc: alSourceAddNotificationProcPtr
        var sourceNotificationProc: alSourceNotificationProc
        
        // create a closure to use as the callback proc for AL_EXT_SOURCE_NOTIFICATIONS
        sourceNotificationProc = {sid, notificationID, userData in
            
            // is it an AL_BUFFER_PROCESSED notification?
            if notificationID == ALuint(AL_BUFFERS_PROCESSED) {
                
//                DispatchQueue.main.async {
                
                    var freeBuffers = [ALuint](repeating: 0, count: kOpusBufferCount)
                    var processed: ALint = 0
                
                    // YES, get a count of "processed" OpenAL buffers
                    alGetSourcei(sid, AL_BUFFERS_PROCESSED, &processed)
                    let alErr = alGetError()
                    if alErr != AL_NO_ERROR { Swift.print("alGetSourcei error") }
                
                    guard processed >= 1 else { return }
                    
                    //                    Swift.print("Processed -> \(processed)")
                    
                    // un-queue the buffer(s) and get their handles
                for i in 0..<Int(processed) {
                    alSourceUnqueueBuffers(sid, ALsizei(1), &freeBuffers[i])
                    let alErr2 = alGetError()
                    if alErr2 != AL_NO_ERROR { Swift.print("alSourceUnqueueBuffers error") }
                }
                
                    Swift.print("processed = \(processed), freeBuffers -> \(freeBuffers)")
                
                    // get a reference to the player struct
                    let player = userData!.bindMemory(to: StreamPlayer.self, capacity: 1)
                
                    // re-fill the un-queue'd OpenAl buffer(s)
                    for i in 0..<Int(processed) {
                        
                        // copy from the Ring Buffer to the OpenAL Buffer
                        alBufferData(freeBuffers[i],
                                     AL_FORMAT_STEREO16,
                                     player.pointee.ringBuffer.deQ(count: kOpusFrameCount * kOpusChannelCount),
                                     ALsizei(kOpusFrameCount * kOpusChannelCount * MemoryLayout<Int16>.size),
                                     ALsizei(kOpusSampleRate))
                    }
                    
                    // re-queue the OpenAL buffer(s) just filled
                    alSourceQueueBuffers(sid, processed, freeBuffers)
                    
                    //                    Swift.print("Requeued -> \(freeBuffer)")
                }
//            }
        }
        
        // determine if the AL_EXT_SOURCE_NOTIFICATIONS extension is present
        if alIsExtensionPresent("AL_EXT_SOURCE_NOTIFICATIONS") == ALboolean(AL_TRUE) {
            
            // can we get the Proc's address?
            if let ptr = alGetProcAddress("alSourceAddNotification") {
                
                // YES, cast it
                sourceAddNotificationProc = unsafeBitCast(ptr, to: alSourceAddNotificationProcPtr.self)
                
                // set the callback (exit if unsuccessful)
                let x = sourceAddNotificationProc(_player.sources[0], ALuint(AL_BUFFERS_PROCESSED), sourceNotificationProc, &_player)
                if x != AL_NO_ERROR {
                    
                    _log.entry("Couldn't perform alSourceAddNotification", level: .error, source: kModule)
                    exit(1)
                }
                
            } else {
                
                // NO, exit
                _log.entry("Couldn't get alSourceAddNotification ProcAddress", level: .error, source: kModule)
                exit(1)
            }
        }
        
//        // determine if the AL_EXT_STATIC_BUFFER extension is present
//        if alIsExtensionPresent("AL_EXT_STATIC_BUFFER") == ALboolean(AL_TRUE) {
//            
//            // can we get the Proc's address?
//            if let ptr = alGetProcAddress("alBufferDataStatic") {
//                
//                // YES, cast it
//                bufferDataStaticProc = unsafeBitCast(ptr, to: alBufferDataStaticProcPtr.self)
//                
//                for i in 0..<kOpusBufferCount {
//                    
//                    // setup the buffer to use Static data
////                    bufferDataStaticProc(ALint(buffers[i]), AL_FORMAT_STEREO16, &buffers[i], ALsizei(kOpusByteCount), ALsizei(kOpusSampleRate) )
//                }
//                
//            } else {
//                
//                // NO, exit
//                Swift.print("Couldn't get alBufferDataStatic ProcAddress")
//                exit(1)
//            }
//        }
    
    }
    //
    // Process the Opus data stream
    //          1. decode
    //          2. add decoded data to Ring Buffer
    //
    
    //  OpusFrame Layout: (see xFlexAPI OpusFrame)
    //      public var samples: [UInt8]                     // array of samples
    //      public var numberOfSamples: Int                 // number of samples
    //

    public func opusStreamHandler(_ frame: OpusFrame) {
        
        
        Swift.print("inUse = \(_player.ringBuffer.inUse), available = \(_player.ringBuffer.available)")
        
        // is there space available in the Ring Buffer?
        if _player.ringBuffer.available >= Int(frame.numberOfSamples) {
            
            // YES, decode the opus stream, place the result in the Ring Buffer
            let decodeResult = opus_decode(_decoder,
                                           frame.samples,
                                           Int32(frame.numberOfSamples),
                                           _player.ringBuffer.enQ(count: kOpusFrameCount * kOpusChannelCount),
                                           Int32(kOpusByteCount), Int32(0))
            
            // check for errors
            if decodeResult != Int32(kOpusFrameCount) {
                
                var error = "Unknown"
                
                switch decodeResult {
                    
                case OPUS_BAD_ARG:
                    error = "bad arg"
                    
                case OPUS_BUFFER_TOO_SMALL:
                    error = "buffer too small"
                    
                case OPUS_INTERNAL_ERROR:
                    error = "internal error"
                    
                case OPUS_INVALID_PACKET:
                    error = "invalid packet"
                    
                case OPUS_UNIMPLEMENTED:
                    error = "unimplemented"
                    
                case OPUS_INVALID_STATE:
                    error = "invalid state"
                    
                case OPUS_ALLOC_FAIL:
                    error = "memory alloc fail"
                    
                default:
                    break
                }
                _log.entry("Opus decoder error, " + error, level: .error, source: kModule)
            }
        }

        // if first buffers, prime the OpenAL Buffers
        if _player.buffersProcessed < kOpusBufferCount{
            
            // get the current OpenAL state
            var state: ALenum = 0
            alGetSourcei(_player.sources[0], AL_SOURCE_STATE, &state)
            
            // place data directly into the OpenAL Buffers
            
            // choose a buffer
            let freeBuffer = buffers[_player.buffersProcessed]

            
            Swift.print("buffer = \(freeBuffer), available = \(_player.ringBuffer.available)")
            
            // copy from the Ring Buffer to the OpenAl buffer
            alBufferData(freeBuffer,
                         AL_FORMAT_STEREO16,
                         _player.ringBuffer.deQ(count: kOpusFrameCount * kOpusChannelCount),
                         ALsizei(kOpusFrameCount * kOpusChannelCount * MemoryLayout<Int16>.size),
                         ALsizei(kOpusSampleRate))
            
            checkAL("Couldn't copy from Ring Buffer")
            
            // queue the OpenAL buffer just filled
            alSourceQueueBuffers(_player.sources[0], 1, [freeBuffer])
            checkAL("Couldn't queue buffer")
            
            _player.buffersProcessed += 1
            
            if _player.buffersProcessed >= kOpusBufferCount {
                
                Swift.print("Play")
                
                // start playing
                alSourcePlayv (1, self._player.sources)
                self.checkAL("Couldn't play")
            }
        }
    }
    //
    //
    //
    func checkAL (_ operation: String) {
        
        let alErr = alGetError()
        
        if alErr == AL_NO_ERROR { return }
        
        var errFormat = ""
        switch alErr {
        case AL_INVALID_NAME:
            errFormat = "OpenAL Error: AL_INVALID_NAME"
        case AL_INVALID_VALUE:
            errFormat = "OpenAL Error: AL_INVALID_VALUE"
        case AL_INVALID_ENUM:
            errFormat = "OpenAL Error: AL_INVALID_ENUM"
        case AL_INVALID_OPERATION:
            errFormat = "OpenAL Error: AL_INVALID_OPERATION"
        case AL_OUT_OF_MEMORY:
            errFormat = "OpenAL Error: AL_OUT_OF_MEMORY"
        default:
            errFormat = "OpenAL Error: unknown error"
        }
        
        _log.entry("\(errFormat), \(operation)", level: .error, source: kModule)
        
        exit(1)
        
    }
}

class RingBuffer {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    private(set) var size = 0                           // size of buffer in Int16's
    var inUse: Int { return head - tail }               // populated Int16's in buffer
    var available: Int { return size - inUse }          // empty Int16's in buffer
    
    // NOTE: head & tail are constantly incremented but MOD'd when used as an index
    //       into the ringBuffer, this will work for 2e16 times for a 2048 Int16 enQueue
    //       at 1 enqueue per 10 ms, that is 2,856,164 years (i.e. don't worry!)
    //
    
//    var headPtr: UnsafeMutablePointer<Int16> {          // ptr to next Int16 to be written
//        
//        return UnsafeMutablePointer<Int16>(mutating: buffer).advanced(by: head & mask)
//    }
//
//    var tailPtr: UnsafeRawPointer {                     // ptr to next byte to be read
//        
//        return UnsafeRawPointer(buffer).advanced(by: (tail * MemoryLayout<Int16>.size) & mask)
//    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var buffer: [Int16]                         // Ring buffer
    private var head = 0                                // location of head (in Int16's)
    private var tail = 0                                // location of tail (in Int16's)
    private var mask = 0                                // mask for head & tail

    private let ringQ = DispatchQueue(label: "xFlexAPI.ringBufferQ", qos: DispatchQoS.userInitiated)
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(size: Int) {                                   // size is power of 2
        
        // calculate the size in Int16's (forced to be a power of 2)
        self.size = Int( pow(2.0, Double(size)) )
        
        // allocate the buffer
        buffer = [Int16](repeating: 0, count: size)
        
        // set the mask used to "Mod" the head & tail (size is always a power of 2)
        mask = size - 1
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    //
    // Clear the buffer (optionally set all bytes to 0 )
    //
    func clear(zero: Bool = false) {
        
        // head = tail = 0 is an empty buffer
        self.head = 0
        self.tail = self.head
        
        // if requested, zero the buffer contents
        if zero { memset(&buffer, 0, size * MemoryLayout<Int16>.size) }
    }
    //
    // Provide a pointer to the tail, advance the tail location
    //
    func deQ(count: Int) -> UnsafeRawPointer {
        
        let tailPtr = UnsafeRawPointer(buffer).advanced(by: (tail * MemoryLayout<Int16>.size) & mask)

        // move the tail
        tail += count
        
        return tailPtr
    }
    //
    // Provide a mutable pointer to the head, advance the head location
    //
    func enQ(count: Int) -> UnsafeMutablePointer<Int16> {
        
        let headPtr = UnsafeMutablePointer<Int16>(mutating: buffer).advanced(by: head & mask)
        
        // move the head
        head += count
        
        return headPtr
    }
}
