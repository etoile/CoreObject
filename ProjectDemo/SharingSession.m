#import "SharingSession.h"
#import "COStoreCoordinator.h"

@implementation SharingSession

- (id) initWithDocument: (Document*)d
{
  self = [super init];
  ASSIGN(doc, d);
  peers = [[NSMutableDictionary alloc] init];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
        selector: @selector(didCommit:)
         name: COStoreDidCommitNotification 
         object: nil];
         
  ASSIGN(sessionID, [ETUUID UUID]);
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [peers release];
  [doc release];
  [sessionID release];
  [super dealloc];
}

/* COStoreCoordinator notification */

- (void)didCommit: (NSNotification*)notif
{
  [NSTimer scheduledTimerWithTimeInterval: 0
                                   target: self
                                 selector: @selector(afterCommits:)
                                 userInfo: nil
                                  repeats: NO];
}

- (void)afterCommits: (NSTimer*)t
{
  NSLog(@"Handle commits...");
}


- (void)addClientNamed: (NSString*)name
{
  SharingSessionPeer *p = [[SharingSessionPeer alloc] initWithSharingSession:self clientName:name];
  [peers setObject: p
            forKey: name];
  [p release];
}
- (void)removeClientNamed: (NSString*)name
{
  [peers removeObjectForKey: name];
}


@end
