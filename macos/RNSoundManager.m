#import "RNSoundManager.h"
#import "RNSound-Swift.h"
#import <React/RCTConvert.h>
#import <React/RCTNetworking.h>
#import <AVFoundation/AVFoundation.h>

@implementation RNSoundManager
{
  Starling *_player;
  NSMutableDictionary<NSNumber *, RCTNetworkTask *> *_loading;
}

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

- (instancetype)init
{
  if (self = [super init]) {
    _player = [Starling new];
    _loading = [NSMutableDictionary new];
  }
  return self;
}

- (dispatch_queue_t)methodQueue
{
  dispatch_queue_attr_t attr =
    dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);

  return dispatch_queue_create("oss.react-native.RNSound", attr);
}

NSString *RCTFailedToLoad(NSURL *url, NSString *message) {
  return [NSString stringWithFormat:@"[RNSound] Failed to load \"%@\": %@", url.absoluteString, message];
}

RCT_REMAP_METHOD(preload,
                 preloadSound:(NSNumber * _Nonnull)identifier
                 source:(id)source
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  // TODO: Check for bundle URLs
  NSURLRequest *request = [RCTConvert NSURLRequest:source];
  if (!request) {
    return reject(RCTErrorUnspecified, @"[RNSound] Expected \"source\" prop to be a URL request", nil);
  }

  NSString *fileType = request.URL.pathExtension;

  RCTNetworkTask *task = [_bridge.networking
    networkTaskWithRequest:request
    completionBlock:^(__unused NSURLResponse *response, NSData *data, NSError *error) {
      self->_loading[identifier] = nil;

      if (error) {
        return reject(RCTErrorUnspecified, RCTFailedToLoad(request.URL, error.localizedDescription), error);
      }

      // TODO: support more file formats?
      AudioInfo *audio = [data readAudioInfo:fileType];
      if (audio == nil) {
        NSString *message = [NSString stringWithFormat:@"Unsupported file format: %@", fileType];
        return reject(RCTErrorUnspecified, RCTFailedToLoad(request.URL, message), nil);
      }
      if (audio.error) {
        return reject(RCTErrorUnspecified,
                      RCTFailedToLoad(request.URL, audio.error.localizedDescription),
                      audio.error);
      }

      // TODO: support more pcm formats?
      AVAudioCommonFormat sampleFormat;
      switch (audio.bitDepth) {
        case 32:
          sampleFormat = AVAudioPCMFormatFloat32;
          break;

        default:
          return reject(RCTErrorUnspecified,
                        RCTFailedToLoad(request.URL, @"The bit depth must be 32-bit float on macOS"),
                        nil);
      }

      NSData *samples = audio.samples;
      AVAudioFormat *format =
        [[AVAudioFormat alloc] initWithCommonFormat:sampleFormat
                                         sampleRate:audio.sampleRate
                                           channels:audio.channels
                                        interleaved:audio.interleaved];

      [self->_player setSound:[samples toPCMBufferWithFormat:format]
                forIdentifier:identifier.stringValue];

      resolve(nil);
    }];

  // Store the task so it can be cancelled.
  _loading[identifier] = task;

  [task start];
}

RCT_REMAP_METHOD(unload,
                 unloadSound:(NSNumber * _Nonnull)identifier)
{
  if (_loading[identifier]) {
    [_loading[identifier] cancel];
    _loading[identifier] = nil;
  } else {
    [_player setSound:nil
        forIdentifier:identifier.stringValue];
  }
}

RCT_REMAP_METHOD(play,
                 playSound:(NSNumber * _Nonnull)identifier
                 options:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (_loading[identifier]) {
    return reject(RCTErrorUnspecified, @"Source not yet loaded", nil);
  }

  float volume = options[@"volume"]
    ? [RCTConvert float:options[@"volume"]]
    : 1.0;

  [_player playSound:identifier.stringValue
              volume:volume
        allowOverlap:YES
     completionBlock:^(NSError * _Nullable error) {
       if (error) {
         reject(RCTErrorUnspecified, error.localizedDescription, error);
       } else {
         resolve(nil);
       }
     }];
}

@end
