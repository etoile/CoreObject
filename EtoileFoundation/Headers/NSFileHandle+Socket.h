#import <Foundation/Foundation.h>

/**
 * @group Network and Communication
 *
 * Category on NSFileHandle which adds support for creating protocol-agnostic
 * sockets.
 */
@interface  NSFileHandle (SocketAdditions)
/**
 * Returns a new file handle object wrapping a connection-oriented stream
 * socket to the specified host on the named service.  
 */
+ (NSFileHandle*) fileHandleConnectedToRemoteHost: (NSString*)aHost
                                       forService: (NSString*)aService;
@end
