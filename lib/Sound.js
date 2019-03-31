"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var tslib_1 = require("tslib");
var react_native_macos_1 = require("react-native-macos");
var RNSound_1 = require("./RNSound");
var nextId = 1;
var Sound = /** @class */ (function () {
    function Sound(_a) {
        var source = _a.source, onLoad = _a.onLoad, onError = _a.onError, opts = tslib_1.__rest(_a, ["source", "onLoad", "onError"]);
        this._id = nextId++;
        this._lastPlayed = 0;
        this._disposed = false;
        this._source = this._resolveSource(source);
        this._props = tslib_1.__assign({ timeout: 0, volume: 1, muted: false }, opts);
        RNSound_1.RNSound.preload(this._id, this._source).then(onLoad, onError ||
            (function (error) {
                throw error;
            }));
    }
    Object.defineProperty(Sound.prototype, "source", {
        /** The bundled sound asset. */
        get: function () {
            return this._source;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Sound.prototype, "timeout", {
        get: function () {
            return this._props.timeout;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Sound.prototype, "volume", {
        /** The volume limit, between 0 and 1. */
        get: function () {
            return this._props.volume;
        },
        set: function (val) {
            this._props.volume = val;
        },
        enumerable: true,
        configurable: true
    });
    Object.defineProperty(Sound.prototype, "muted", {
        /** Useful for muting a sound without affecting its `volume` prop. */
        get: function () {
            return this._props.muted;
        },
        set: function (val) {
            this._props.muted = val;
        },
        enumerable: true,
        configurable: true
    });
    /** Play the sound once. */
    Sound.prototype.play = function (options) {
        if (options === void 0) { options = {}; }
        if (this._disposed) {
            throw Error('Cannot play a Sound after calling its "dispose" method');
        }
        if (this.muted) {
            return;
        }
        var now = Date.now();
        if (this.timeout <= 0 || now - this._lastPlayed >= this.timeout) {
            this._lastPlayed = now;
            return RNSound_1.RNSound.play(this._id, tslib_1.__assign({ volume: this._props.volume }, options));
        }
    };
    /** Unload the sound asset. This instance cannot be reused. */
    Sound.prototype.dispose = function () {
        if (!this._disposed) {
            this._disposed = true;
            RNSound_1.RNSound.unload(this._id);
        }
    };
    Sound.prototype._resolveSource = function (source) {
        var uri = react_native_macos_1.Image.resolveAssetSource(source).uri;
        if (!hasExtension(uri, '.wav')) {
            throw Error('The "source" prop must have a .wav extension');
        }
        return uri;
    };
    return Sound;
}());
exports.Sound = Sound;
function hasExtension(uri, ext) {
    var queryIndex = uri.indexOf('?');
    return (queryIndex < 0 ? uri : uri.slice(0, queryIndex)).endsWith(ext);
}
