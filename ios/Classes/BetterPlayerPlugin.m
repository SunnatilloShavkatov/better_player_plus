#import "BetterPlayerPlugin.h"
#if __has_include(<xstream_player/xstream_player-Swift.h>)
#import <xstream_player/xstream_player-Swift.h>
#else
#import "xstream_player-Swift.h"
#endif

@implementation BetterPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftBetterPlayerPlugin registerWithRegistrar:registrar];
}
@end
