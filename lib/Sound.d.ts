import { ImageRequireSource } from 'react-native-macos';
interface SoundProps {
    /** Limit the number of plays per time period (in ms). */
    timeout: number;
    /** The volume limit, between 0 and 1. */
    volume: number;
    /** Useful for muting a sound without affecting its `volume` prop. */
    muted: boolean;
}
export declare class Sound implements SoundProps {
    private _id;
    private _source;
    private _props;
    private _lastPlayed;
    private _disposed;
    constructor({ source, onLoad, onError, ...opts }: Partial<SoundProps> & {
        /** The bundled sound asset. Must have a `.wav` extension. */
        source: ImageRequireSource;
        /** Called once the sound is ready to play. */
        onLoad?: () => void;
        /** Called if the sound fails to load. */
        onError?: (error: Error) => void;
    });
    /** The bundled sound asset. */
    readonly source: string;
    readonly timeout: number;
    /** The volume limit, between 0 and 1. */
    volume: number;
    /** Useful for muting a sound without affecting its `volume` prop. */
    muted: boolean;
    /** Play the sound once. */
    play(options?: {
        volume?: number;
    }): Promise<void> | undefined;
    /** Unload the sound asset. This instance cannot be reused. */
    dispose(): void;
    private _resolveSource;
}
export {};
