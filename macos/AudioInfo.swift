import Foundation

public class AudioInfo : NSObject {
  @objc public required init(input: Data) {
    self.input = input
    super.init()
  }

  /** The parsed data */
  @objc public let input: Data

  /** Number of samples per second per channel */
  @objc public var sampleRate: UInt32 = 0

  /** Bits per sample */
  @objc public var bitDepth: UInt16 = 0

  /** Number of channels (1 for mono, 2 for stereo) */
  @objc public var channels: UInt16 = 0

  /** Applicable to stereo formats only */
  @objc public var interleaved = false

  /** Return an Error if this data cannot be played */
  @objc public var error: Error?

  /** Contiguous buffer of sample data */
  @objc public var samples: Data {
    preconditionFailure("This method must be overridden")
  }

  public override var description: String {
    let description = super.description.dropLast()
    if let error = self.error {
      return "\(description); error = \"\(error.localizedDescription)\";>"
    }
    return "\(description); sampleRate = \(self.sampleRate); bitDepth = \(self.bitDepth); channels = \(self.channels); bytes = \(input.count);>"
  }
}

// Useful for parsing buffers:
extension UnsignedInteger {
  init(_ bytes: ArraySlice<UInt8>) {
    precondition(bytes.count <= MemoryLayout<Self>.size)

    var value: UInt64 = 0

    for byte in bytes.reversed() {
      value <<= 8
      value |= UInt64(byte)
    }

    self.init(value)
  }
}
