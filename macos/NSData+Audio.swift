import AVFoundation

extension NSData {
  // Taken from: https://stackoverflow.com/a/52731480/2228559
  @objc public func toPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
    let data = self as Data
    let streamDesc = format.streamDescription.pointee
    let frameCapacity = UInt32(data.count) / streamDesc.mBytesPerFrame

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
    else { return nil }

    buffer.frameLength = frameCapacity
    let audioBuffer = buffer.audioBufferList.pointee.mBuffers

    data.withUnsafeBytes {
      audioBuffer.mData?.copyMemory(from: $0, byteCount: Int(audioBuffer.mDataByteSize))
    }

    return buffer
  }

  @objc public func readAudioInfo(_ ext: String) -> AudioInfo? {
    switch (ext) {
      case "wav":
        return WavInfo(input: self as Data)
      default:
        return nil
    }
  }
}
