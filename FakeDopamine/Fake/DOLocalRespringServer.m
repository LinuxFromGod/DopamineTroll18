//
//  DOLocalRespringServer.m
//  Dopamine
//

#import "DOLocalRespringServer.h"
#import <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

// Minimal HTTP/1.0 server: one socket, bound to loopback only, one-shot
// request handling on a background queue. Just enough for Safari to GET the
// payload page; nothing else can reach it.
@interface DOLocalRespringServer ()
@property (nonatomic, assign) CFSocketRef listenSocket;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSData *response;
@end

@implementation DOLocalRespringServer

+ (instancetype)sharedServer
{
    static DOLocalRespringServer *sharedServer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedServer = [[DOLocalRespringServer alloc] init];
    });
    return sharedServer;
}

- (BOOL)startWithHTML:(NSString *)html
{
    [self stop];

    NSData *body = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *full = [NSMutableData new];
    NSString *head = [NSString stringWithFormat:
        @"HTTP/1.0 200 OK\r\n"
         "Content-Type: text/html; charset=utf-8\r\n"
         "Content-Length: %lu\r\n"
         "Cache-Control: no-store\r\n"
         "Connection: close\r\n\r\n", (unsigned long)body.length];
    [full appendData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    [full appendData:body];
    self.response = full;

    CFSocketContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    self.listenSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                                       kCFSocketAcceptCallBack, &DOLocalRespringServerAccept, &context);
    if (!self.listenSocket)
        return NO;

    // Bind to 127.0.0.1 with an ephemeral port, loopback only
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;

    CFDataRef addrData = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)&addr, sizeof(addr));
    CFSocketError err = CFSocketSetAddress(self.listenSocket, addrData);
    CFRelease(addrData);
    if (err != kCFSocketSuccess) {
        [self stop];
        return NO;
    }

    UInt16 port = 0;
    CFDataRef localAddr = CFSocketCopyAddress(self.listenSocket);
    if (localAddr) {
        const struct sockaddr_in *sin = (const struct sockaddr_in *)CFDataGetBytePtr(localAddr);
        port = ntohs(sin->sin_port);
        CFRelease(localAddr);
    }
    if (port == 0) {
        [self stop];
        return NO;
    }

    self.url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/", port]];

    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, self.listenSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CFRelease(source);

    return YES;
}

- (void)stop
{
    if (self.listenSocket) {
        CFSocketInvalidate(self.listenSocket);
        CFRelease(self.listenSocket);
        self.listenSocket = NULL;
    }
    self.url = nil;
    self.response = nil;
}

// Reads the request, writes the canned response, closes. The payload only
// needs one GET; anything else still gets the page so retries work.
static void DOLocalRespringServerAccept(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    DOLocalRespringServer *server = (__bridge DOLocalRespringServer *)info;
    CFSocketNativeHandle client = *(const CFSocketNativeHandle *)data;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buf[2048];
        read(client, buf, sizeof(buf) - 1); // request; contents ignored
        NSData *response = server.response;
        if (response)
            write(client, response.bytes, (size_t)response.length);
        close(client);
    });
}

@end
