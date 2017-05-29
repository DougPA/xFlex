//
//  OpusManager.swift
//  xFlex
//
//  Created by Douglas Adams on 2/12/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation
import xFlexAPI
import OpusOSX
import AudioLibrary
import Accelerate

class OpusManager : NSObject, OpusStreamHandler, AFSoundcardDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _decoder: OpaquePointer!                        // Opaque pointer to Opus Decoder
    fileprivate var _encoder: OpaquePointer!                        // Opaque pointer to Opus Encoder
    fileprivate let _audioManager = AFManager()                     // AudioLibrary manager
    fileprivate var _outputSampleCount: Int!                        // Number of decoded samples expected

    fileprivate let _outputSoundcard: AFSoundcard?                  // audio output device
    fileprivate var _rxInterleavedBuffer: [Float]!                  // output of Opus decoder
    fileprivate let _rxBufferHead: UnsafeMutablePointer<Float>!
    fileprivate var _rxBufferList: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
    fileprivate var _rxSplitComplex: DSPSplitComplex
    fileprivate let _rxLeftBuffer: [Float]!                         // non-interleaved buffer, Left
    fileprivate let _rxRightBuffer: [Float]!                        // non-interleaved buffer, Right
    
    fileprivate let _inputSoundcard: AFSoundcard?                   // audio input device
//    fileprivate var _txComplex: DSPComplex
    fileprivate var _txInterleaved: [Float]!
    fileprivate let _txLeftBuffer: [Float]!                         // non-interleaved buffer, Left
    fileprivate let _txRightBuffer: [Float]!                        // non-interleaved buffer, Right
    fileprivate var _txEncodedBuffer: [UInt8]!
    fileprivate let _txEncodedBufferHead: UnsafeMutablePointer<UInt8>!
    

    // constants
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kModule = "OpusDecoder"                         // Module Name reported in log messages
    fileprivate let kSampleRate: Float = 24_000                     // Sample Rate (samples/second)
    fileprivate let kNumberOfChannels = 2                           // Stereo, Right & Left channels
    fileprivate let kStereoChannelMask: Int32 = 0x3
    
    fileprivate let kMaxEncodedBytes = 512                          // max size of encoded frame
    
    fileprivate enum OpusApplication: Int32 {                       // Opus "application" values
        case voip = 2048
        case audio = 2049
        case restrictedLowDelay = 2051
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    override init() {
        
        _outputSampleCount = Int(kSampleRate * 0.01)                // 10 ms worth
        
        // RX STREAM setup (audio from the Radio to the Mac)

        // setup the sound output unit
        _outputSoundcard = _audioManager.newOutputSoundcard()
        guard _outputSoundcard != nil else { fatalError("Unable to create output sound card") }
        _outputSoundcard!.setSamplingRate(kSampleRate)
        _outputSoundcard!.setBufferLength(Int32(_outputSampleCount))
        _outputSoundcard!.setChannelMask(kStereoChannelMask)
        
        // allocate the interleaved Rx buffer
        _rxInterleavedBuffer = [Float](repeating: 0.0, count: _outputSampleCount * kNumberOfChannels)
        
        // get a pointer to the start of the interleaved Rx buffer
        _rxBufferHead = UnsafeMutablePointer<Float>(mutating: _rxInterleavedBuffer)
        
        // allocate the non-interleaved Rx buffers
        _rxLeftBuffer = [Float](repeating: 0.0, count: _outputSampleCount)
        _rxRightBuffer = [Float](repeating: 0.0, count: _outputSampleCount)
        
        // allocate an Rx buffer list & initialize it
        _rxBufferList = UnsafeMutablePointer<UnsafeMutablePointer<Float>?>.allocate(capacity: 2)
        _rxBufferList[0] = UnsafeMutablePointer(mutating: _rxLeftBuffer)
        _rxBufferList[1] = UnsafeMutablePointer(mutating: _rxRightBuffer)
        
        // view the non-interleaved Rx buffers as a DSPSplitComplex (for vDSP)
        _rxSplitComplex = DSPSplitComplex(realp: _rxBufferList[0]!, imagp: _rxBufferList[1]!)

        // create the Opus decoder
        var opusError: Int32 = 0
        _decoder = opus_decoder_create(Int32(kSampleRate), 2, &opusError)
        if opusError != 0 { fatalError("Unable to create OpusDecoder, error = \(opusError)") }
        
        // TX STREAM setup (audio from the Mac to the Radio)

        // setup the sound input unit
        _inputSoundcard = _audioManager.newInputSoundcard()
        guard _inputSoundcard != nil else { fatalError("Unable to create input sound card") }
        _inputSoundcard!.setSamplingRate(kSampleRate)
        _inputSoundcard!.setBufferLength(Int32(512))
        _inputSoundcard!.setChannelMask(kStereoChannelMask)
        
        // initialize the interleaved Tx encoded buffer & get a pointer to its start
        _txEncodedBuffer = [UInt8](repeating: 0, count: kMaxEncodedBytes)
        _txEncodedBufferHead = UnsafeMutablePointer<UInt8>(mutating: _txEncodedBuffer)
        
        // allocate the non-interleaved Tx buffers
        _txLeftBuffer = [Float](repeating: 0.0, count: 512)
        _txRightBuffer = [Float](repeating: 0.0, count: 512)
        
//        // view the non-interleaved Tx buffers as a DSPComplex (for vDSP)
//        _txComplex = DSPComplex(real: _txLeftBuffer[0], imag: _txRightBuffer[0])
        
        _txInterleaved = [Float](repeating: 0.0, count: 2 * 512)
        
        // create the Opus encoder
        _encoder = opus_encoder_create(Int32(kSampleRate), 2, OpusApplication.audio.rawValue, &opusError)
        if opusError != 0 { fatalError("Unable to create OpusEncoder, error = \(opusError)") }

        super.init()
        
        _inputSoundcard!.setDelegate(self)
        _outputSoundcard!.setDelegate(self)
    }
    /// Perform any required cleanup
    ///
    deinit {
        
        // stop output (if any)
        _outputSoundcard?.stop()
        
        // de-allocate the Rx buffer list
        _rxBufferList.deallocate(capacity: 2)
        
    }
    /// Start/Stop the Opus Rx stream processing
    ///
    /// - Parameter start:      true = start
    ///
    func rxAudio(_ start: Bool) {
        
//        print("rxAudio - \(start ? "start" : "stop")")
        
        if start {
            _outputSoundcard?.start()
        } else {
            _outputSoundcard?.stop()
        }
    }
    /// Start/Stop the Opus Tx stream processing
    ///
    /// - Parameter start:      true = start
    ///
    func txAudio(_ start: Bool) {

//        print("txAudio - \(start ? "start" : "stop")")
        
        if start {
            _inputSoundcard?.start()
        } else {
            _inputSoundcard?.stop()
        }
    }
        
    func inputReceived(from card: AFSoundcard!, buffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!, numberOfBuffers n: Int32, samples: Int32) {
    
        // buffers is a "bufferList" with buffers[0] = left & buffers[1] = right
        
        // make sure we have stereo
        guard n == 2 else { return }
        
//        // view the left & right channels as a DSPSplitComplex (for vDSP)
//        var txSplitComplex = DSPSplitComplex(realp: buffers[0]!, imagp: buffers[1]!)
        
        // convert the nonInterleaved samples to Interleaved
        for i in 0..<Int(samples) {
            
            _txInterleaved[2*i] = buffers[0]![i]
            _txInterleaved[(2*i)+1] = buffers[1]![i]
        }
        
        print("Samples = \(samples)")
        

//        // convert the samples from the left & right (non-interleaved) buffers to an interleaved buffer
//        vDSP_ztoc(&txSplitComplex, vDSP_Stride(1), &_txComplex, 2, vDSP_Length(samples))
        
//        // obtain a pointer to the beginning of the interleaved buffer
//        let txBufferHead = UnsafeMutablePointer<Float>(mutating: &_txInterleaved[0])
        
        // encode the bytes
        let encodeResult = opus_encode_float(_encoder, &_txInterleaved[0], samples, &_txEncodedBuffer[0], Int32(kMaxEncodedBytes))

        // check for errors
        if encodeResult < 0 { (NSApp.delegate as! LogHandler).message(String(cString: opus_strerror(encodeResult)), level: .error, source: kModule)}
        
        // TODO: send to Radio
        print("Encode = \(String(cString: opus_strerror(encodeResult)))")
        
        
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - OpusStreamHandler protocol methods
    //      called by Opus, executes on the udpQ
    //
    
    /// Process an Opus stream
    ///
    /// - Parameter frame: an Opus Frame
    ///
    func opusStreamHandler(_ frame: OpusFrame) {
        
        // perform Opus decoding
        let decodeResult = opus_decode_float(_decoder, frame.samples, Int32(frame.numberOfSamples), _rxBufferHead, Int32(_outputSampleCount * MemoryLayout<Float>.size * kNumberOfChannels), Int32(0))
        
        // check for decode errors
        if decodeResult < 0 { (NSApp.delegate as! LogHandler).message(String(cString: opus_strerror(decodeResult)), level: .error, source: kModule) }
        
        // convert the decoded audio from interleaved to non-interleaved
        _rxBufferHead.withMemoryRebound(to: DSPComplex.self, capacity: 1) { bufferHeadDSP in
            vDSP_ctoz(bufferHeadDSP, kNumberOfChannels, &_rxSplitComplex, 1, vDSP_Length(decodeResult))
        }
        
        // push the non-interleaved audio to the output device
        _outputSoundcard?.pushBuffers(_rxBufferList, numberOfBuffers: Int32(kNumberOfChannels), samples: Int32(decodeResult), rateScalar: 1.0)
    }
}
