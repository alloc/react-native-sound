# @alloc/react-native-sound

### 🚧 Under construction

Sound effect player for [react-native-macos](https://github.com/ptmt/react-native-macos)

```ts
import {Sound} from '@alloc/react-native-sound'

// When a Sound is constructed, its source is pre-loaded.
const foo = new Sound({
  source: require('./foo.wav'),
  // Throttle the sound to once per second
  timeout: 1000,
  // The volume limit (between 0 and 1)
  volume: 0.5,
  // Mute the sound without modifying `volume`
  muted: true,
  // Called once the sound is ready to play
  onLoad: () => {},
  // Called when the sound fails to load
  onError: (error) => {
    // The default behavior
    throw error
  },
})

// Play once
foo.play()

// Some options can be mutated after creation
foo.volume = 0
foo.muted = false

// Release memory
foo.dispose()
```

## Notes

Works on macOS 10.13+

Thanks to [Starling](https://github.com/matthewreagan/Starling) for providing much of the native implementation.

Type definitions included!! (TypeScript only)
