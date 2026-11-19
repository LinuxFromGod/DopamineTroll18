//
//  DOLocalRespringServer.h
//  Dopamine
//
//  Tiny loopback-only HTTP server used to serve the WebRespring payload to
//  Safari from inside the app. Safari's WebKit context is where the payload
//  is verified to take SpringBoard down on stock devices, so it is opened
//  there instead of an in-process WKWebView.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOLocalRespringServer : NSObject

+ (instancetype)sharedServer;

// Serves the given HTML on 127.0.0.1 with an ephemeral port. Returns NO when
// the listener could not be created.
- (BOOL)startWithHTML:(NSString *)html;

// The URL the payload is served at ("http://127.0.0.1:<port>/"), or nil when
// the server is not running.
@property (nonatomic, readonly, strong, nullable) NSURL *url;

@end

NS_ASSUME_NONNULL_END
