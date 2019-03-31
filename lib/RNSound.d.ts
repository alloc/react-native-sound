export declare const RNSound: {
    preload(soundId: number, source: string): Promise<void>;
    unload(soundId: number): void;
    play(soundId: number, options?: {
        volume?: number;
    }): Promise<void>;
};
