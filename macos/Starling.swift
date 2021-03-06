//
//  Starling
//
//  Released under: MIT License
//  Copyright (c) 2018 by Matt Reagan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import AVFoundation

/// Typealias used for identifying specific sound effects
public typealias SoundIdentifier = String

/// Errors specific to Starling's loading or playback functions
enum StarlingError: Error {
  case invalidSoundIdentifier(_ name: String)
  case audioLoadingFailure
}

public class Starling : NSObject {

  /// Defines the number of players which Starling instantiates
  /// during initialization. If more concurrent sounds than this
  /// are requested at any point, Starling will allocate additional
  /// players as needed, up to `maximumTotalPlayers`.
  private static let defaultStartingPlayerCount = 8

  /// Defines the total number of concurrent sounds which Starling
  /// will allow to be played at the same time. If (N) sounds are
  /// already playing and another play() request is made, it will
  /// be ignored (not queued).
  private static let maximumTotalPlayers = 48

 // MARK: - Internal Properties

  private var players = [StarlingAudioPlayer]()
  private var sounds = [String: AVAudioPCMBuffer]()
  private let engine = AVAudioEngine()

  // MARK: - Initializer

  public override init() {
    assert(Starling.defaultStartingPlayerCount <= Starling.maximumTotalPlayers, "Invalid starting and max audio player counts.")
    assert(Starling.defaultStartingPlayerCount > 0, "Starting audio player count must be > 0.")

    super.init()

    let _ = engine.mainMixerNode
    engine.prepare()

    for _ in 0 ..< Starling.defaultStartingPlayerCount {
      players.append(StarlingAudioPlayer())
    }

    NotificationCenter.default.addObserver(
      forName: .ComponentInstanceInvalidation,
      object: nil,
      queue: nil,
      using: componentInstanceInvalidated
    )
  }

  deinit {
    engine.stop()
    NotificationCenter.default.removeObserver(
      componentInstanceInvalidated,
      name: .ComponentInstanceInvalidation,
      object: nil
    )
  }

  // MARK: - Public API (Adding Sounds)

  @objc(setSound:forIdentifier:)
  public func set(sound: AVAudioPCMBuffer?, for identifier: SoundIdentifier) {
    // Note: self is used as the lock pointer here to avoid
    // the possibility of locking on _swiftEmptyDictionaryStorage
    objc_sync_enter(self)
    sounds[identifier] = sound
    objc_sync_exit(self)
  }

  // MARK: - Public API (Playback)

  @objc(playSound:volume:allowOverlap:completionBlock:)
  public func play(
    _ sound: SoundIdentifier,
    volume: Float,
    allowOverlap: Bool,
    _ callback: @escaping (Error?) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.performSoundPlayback(
        sound,
        volume: volume,
        allowOverlap: allowOverlap,
        callback
      )
    }
  }

  // MARK: - Internal Functions

  private func componentInstanceInvalidated(notification: Notification) {
    let unit = notification.object as? AUAudioUnit
    print("AUAudioUnit crashed: \(unit?.debugDescription ?? notification.debugDescription)")
  }

  private func performSoundPlayback(
    _ identifier: SoundIdentifier,
    volume: Float,
    allowOverlap: Bool,
    _ callback: @escaping (Error?) -> Void
  ) {
    // Note: self is used as the lock pointer here to avoid
    // the possibility of locking on _swiftEmptyDictionaryStorage
    objc_sync_enter(self)
    let sound = sounds[identifier]
    objc_sync_exit(self)

    if sound == nil {
      callback(StarlingError.invalidSoundIdentifier(identifier))
      return
    }

    func performPlaybackOnFirstAvailablePlayer() {
      guard let player = firstAvailablePlayer() else { return }

      if player.node.engine == nil {
        engine.attach(player.node)
      }

      // Ensure the player node has the correct format.
      engine.connect(player.node, to: engine.mainMixerNode, format: sound!.format)

      do {
        // Ensure the audio engine is running.
        try engine.start()
      } catch {
        print("AVAudioEngine failed to start: \(error)")
        return
      }

      player.volume = volume
      player.play(sound!, for: identifier, callback)
    }

    if allowOverlap {
      performPlaybackOnFirstAvailablePlayer()
    } else {
      if !soundIsCurrentlyPlaying(identifier) {
        performPlaybackOnFirstAvailablePlayer()
      }
    }
  }

  private func soundIsCurrentlyPlaying(_ sound: SoundIdentifier) -> Bool {
    objc_sync_enter(players)
    defer { objc_sync_exit(players) }
    // TODO: This O(n) loop could be eliminated by simply keeping a playback tally
    for player in players {
      let state = player.state
      if state.status != .idle && state.sound == sound {
        return true
      }
    }
    return false
  }

  private func firstAvailablePlayer() -> StarlingAudioPlayer? {
    objc_sync_enter(players)
    defer { objc_sync_exit(players) }
    let player: StarlingAudioPlayer? = {
      // TODO: A better solution would be to actively manage a pool of available player references
      // For almost every general use case of this library, however, this performance penalty is trivial
      var player = players.first(where: { $0.state.status == .idle })
      if player == nil && players.count < Starling.maximumTotalPlayers {
        player = StarlingAudioPlayer()
        players.append(player!)
      }
      return player
    }()

    return player
  }
}

/// The internal playback status. This is somewhat redundant at the moment given that
/// it should effectively mimic -isPlaying on the node, however it may be extended in
/// the future to represent other non-binary playback modes.
///
/// - idle: No sound is currently playing.
/// - playing: A sound is playing.
/// - looping: (Not currently implemented)
private enum PlayerStatus {
  case idle
  case playing
  case looping
}

private struct PlayerState {
  let sound: SoundIdentifier?
  let status: PlayerStatus

  static func idle() -> PlayerState {
    return PlayerState(sound: nil, status: .idle)
  }
}

private class StarlingAudioPlayer {
  let node = AVAudioPlayerNode()
  var state: PlayerState = .idle()
  var volume: Float = 1

  func play(_ buffer: AVAudioPCMBuffer, for identifier: SoundIdentifier, _ callback: @escaping (Error?) -> Void) {
    assert(node.engine?.isRunning == true, "Not attached to a running engine")
    node.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataPlayedBack) {
      [weak self] callbackType in
      self?.didCompletePlayback(for: identifier, callback)
    }
    state = PlayerState(sound: identifier, status: .playing)
    node.volume = volume
    node.play()
  }

  func didCompletePlayback(for identifier: SoundIdentifier, _ callback: (Error?) -> Void) {
    state = PlayerState.idle()
    callback(nil)
  }
}

extension StarlingError: CustomStringConvertible {
  var description: String {
    switch self {
    case .invalidSoundIdentifier(let name):
      return "Invalid identifier. No sound loaded named '\(name)'"
    case .audioLoadingFailure:
      return "Could not load audio data"
    }
  }
}

extension Data {
  // Taken from: https://stackoverflow.com/a/52731480/2228559
  func toPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
    let streamDesc = format.streamDescription.pointee
    let frameCapacity = UInt32(count) / streamDesc.mBytesPerFrame
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
    else { return nil }

    let samples = buffer.audioBufferList.pointee.mBuffers
    self.withUnsafeBytes { addr in
      samples.mData?.copyMemory(from: addr, byteCount: Int(samples.mDataByteSize))
    }

    buffer.frameLength = frameCapacity
    return buffer
  }
}

extension Notification.Name {
  static let ComponentInstanceInvalidation = Notification.Name(
    rawValue: kAudioComponentInstanceInvalidationNotification as String
  )
}
