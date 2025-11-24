//
//  BetterPlayerAnalyticsListener.h
//  xstream_player
//
//  Simple analytics implementation matching Android implementation
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

// Main analytics listener
@interface BetterPlayerAnalyticsListener : NSObject

@property(nonatomic, strong) FlutterEventSink eventSink;
@property(nonatomic, weak) AVPlayer* player;
@property(nonatomic, strong) NSString* playerKey;

- (instancetype)initWithEventSink:(FlutterEventSink)eventSink 
                           player:(AVPlayer*)player 
                              key:(NSString*)key;

- (void)startListening;
- (void)stopListening;

// Internal methods
- (void)sendErrorEvent:(NSError*)error;
- (NSString*)getErrorType:(NSError*)error;

@end

NS_ASSUME_NONNULL_END 