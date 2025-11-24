#import "BetterPlayerAnalyticsListener.h"

@implementation BetterPlayerAnalyticsListener

- (instancetype)initWithEventSink:(FlutterEventSink)eventSink 
                           player:(AVPlayer*)player 
                              key:(NSString*)key {
    self = [super init];
    if (self) {
        _eventSink = eventSink;
        _player = player;
        _playerKey = key;
        
        NSLog(@"[BetterPlayerAnalytics] Analytics listener initialized for key: %@", key);
    }
    return self;
}

- (void)startListening {
    NSLog(@"[BetterPlayerAnalytics] Starting analytics listening");
    
    // Add player observer for item changes
    [_player addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
    
    // Setup current item listeners if available
    if (_player.currentItem) {
        [self setupItemListeners:_player.currentItem];
    }
}

- (void)stopListening {
    NSLog(@"[BetterPlayerAnalytics] Stopping analytics listening");
    
    // Cleanup observers
    @try {
        [_player removeObserver:self forKeyPath:@"currentItem"];
    } @catch (NSException *exception) {
        NSLog(@"[BetterPlayerAnalytics] Exception removing observer: %@", exception.description);
    }
    
    if (_player.currentItem) {
        [self removeItemListeners:_player.currentItem];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem"]) {
        AVPlayerItem* newItem = change[NSKeyValueChangeNewKey];
        if (newItem && newItem != [NSNull null]) {
            [self setupItemListeners:newItem];
        }
    }
}

- (void)setupItemListeners:(AVPlayerItem*)item {
    [self removeItemListeners:item];
    
    // Core playback notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleItemFailure:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:item];
    
    NSLog(@"[BetterPlayerAnalytics] Listeners setup for item");
}

- (void)removeItemListeners:(AVPlayerItem*)item {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
}

#pragma mark - Event Handlers

- (void)handleItemFailure:(NSNotification*)notification {
    AVPlayerItem* item = notification.object;
    if (item.error) {
        [self sendErrorEvent:item.error];
        NSLog(@"[BetterPlayerAnalytics] Error event sent: %@", item.error.localizedDescription);
    }
}

#pragma mark - Analytics Events

- (void)sendErrorEvent:(NSError*)error {
    if (!_eventSink) return;
    
    NSMutableDictionary* eventData = [NSMutableDictionary dictionary];
    eventData[@"event"] = @"analytics";
    eventData[@"collector"] = @"error";
    eventData[@"type"] = [self getErrorType:error];
    eventData[@"code"] = error.domain;
    eventData[@"message"] = error.localizedDescription ?: @"Unknown error";
    eventData[@"description"] = error.localizedFailureReason ?: @"";
    eventData[@"stack_trace"] = [NSString stringWithFormat:@"Error Domain: %@, Code: %ld", error.domain, (long)error.code];
    
    if ([NSThread isMainThread]) {
        _eventSink(eventData);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_eventSink) {
                self->_eventSink(eventData);
            }
        });
    }
}

- (NSString*)getErrorType:(NSError*)error {
    NSString* domain = error.domain;
    NSInteger code = error.code;
    
    if ([domain isEqualToString:NSURLErrorDomain]) {
        return @"networkError";
    }
    
    if ([domain isEqualToString:AVFoundationErrorDomain]) {
        switch (code) {
            case AVErrorUnknown:
            case AVErrorMediaServicesWereReset:
                return @"otherError";
            case AVErrorMediaDiscontinuity:
            case AVErrorFormatUnsupported:
            case AVErrorFileFormatNotRecognized:
                return @"parsingError";
            case AVErrorDecoderNotFound:
            case AVErrorDecoderTemporarilyUnavailable:
            case AVErrorEncoderNotFound:
            case AVErrorEncoderTemporarilyUnavailable:
                return @"mediaError";
            case AVErrorContentIsProtected:
            case AVErrorNoImageAtTime:
                return @"keySystemError";
            default:
                return @"mediaError";
        }
    }
    
    return @"otherError";
}

- (void)dealloc {
    [self stopListening];
}

@end 