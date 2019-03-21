import Foundation

public enum WavError: Error {
  case invalidFormat
}

public class WavInfo: AudioInfo {

  public required init(input: Data) {
    super.init(input: input)

    let header = [UInt8](input.subdata(in: 0 ..< 44))
    self.error = validate(header)

    if self.error == nil {
      self.channels = UInt16(header[22 ..< 24])
      self.sampleRate = UInt32(header[24 ..< 28])
      self.bitDepth = UInt16(header[34 ..< 36])
    }
  }

  public override var samples: Data {
    return input.subdata(in: 44 ..< input.count)
  }

  // TODO: More validation
  func validate(_ header: [UInt8]) -> Error? {
    let formatBytes = header[0 ..< 4] + header[8 ..< 12] + header[12 ..< 16]
    if let format = String(bytes: formatBytes, encoding: .utf8) {
      if format != "RIFFWAVEfmt " {
        return WavError.invalidFormat
      }
    }
    return nil
  }
}

extension WavError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .invalidFormat:
      return "Invalid RIFF header format"
    }
  }
}
