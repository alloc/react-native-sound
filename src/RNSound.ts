import { NativeModules } from 'react-native-macos'

export const RNSound: {
  preload(soundId: number, source: string): Promise<void>
  unload(soundId: number): void
  play(soundId: number, options?: { volume?: number }): Promise<void>
} = NativeModules.RNSoundManager
