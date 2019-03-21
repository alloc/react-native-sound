import { Image, ImageRequireSource } from 'react-native-macos'
import { RNSound } from './RNSound'

let nextId = 1

// Sound options with properties of the same type.
interface SoundProps {
  /** Limit the number of plays per time period (in ms). */
  timeout: number
  /** The volume limit, between 0 and 1. */
  volume: number
  /** Useful for muting a sound without affecting its `volume` prop. */
  muted: boolean
}

export class Sound implements SoundProps {
  private _id = nextId++
  private _source: string
  private _props: SoundProps
  private _lastPlayed = 0
  private _disposed = false

  constructor({
    source,
    onLoad,
    onError,
    ...opts
  }: Partial<SoundProps> & {
    /** The bundled sound asset. Must have a `.wav` extension. */
    source: ImageRequireSource
    /** Called once the sound is ready to play. */
    onLoad?: () => void
    /** Called if the sound fails to load. */
    onError?: (error: Error) => void
  }) {
    this._source = this._resolveSource(source)
    this._props = {
      timeout: 0,
      volume: 1,
      muted: false,
      ...opts,
    }

    RNSound.preload(this._id, this._source).then(
      onLoad,
      onError ||
        (error => {
          throw error
        })
    )
  }

  /** The bundled sound asset. */
  get source() {
    return this._source
  }

  get timeout() {
    return this._props.timeout
  }

  /** The volume limit, between 0 and 1. */
  get volume() {
    return this._props.volume
  }
  set volume(val: number) {
    this._props.volume = val
  }

  /** Useful for muting a sound without affecting its `volume` prop. */
  get muted() {
    return this._props.muted
  }
  set muted(val: boolean) {
    this._props.muted = val
  }

  /** Play the sound once. */
  play(options: { volume?: number } = {}) {
    if (this._disposed) {
      throw Error('Cannot play a Sound after calling its "dispose" method')
    }
    if (this.muted) {
      return
    }
    const now = Date.now()
    if (this.timeout <= 0 || now - this._lastPlayed >= this.timeout) {
      this._lastPlayed = now
      return RNSound.play(this._id, {
        volume: this._props.volume,
        ...options,
      })
    }
  }

  /** Unload the sound asset. This instance cannot be reused. */
  dispose() {
    if (!this._disposed) {
      this._disposed = true
      RNSound.unload(this._id)
    }
  }

  private _resolveSource(source: ImageRequireSource) {
    const { uri } = Image.resolveAssetSource(source)
    if (!hasExtension(uri, '.wav')) {
      throw Error('The "source" prop must have a .wav extension')
    }
    return uri
  }
}

function hasExtension(uri: string, ext: string) {
  const queryIndex = uri.indexOf('?')
  return (queryIndex < 0 ? uri : uri.slice(0, queryIndex)).endsWith(ext)
}
