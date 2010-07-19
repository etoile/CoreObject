#import "COStore.h"
#import <Foundation/Foundation.h>

@implementation COStore

- (id) initWithURL: (NSURL *)url
{
  self = [super init];
  _url = [url retain];
  
  BOOL isDirectory;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: [_url path] isDirectory: &isDirectory];
  
  if (!exists)
  {
    if ([[NSFileManager defaultManager] createDirectoryAtPath:[_url path]
                                        withIntermediateDirectories: NO
                                                          attributes: nil
                                                              error: NULL])
    {
      NSLog(@"Success creating directory %@", [_url path]);
    }
    else
    {
      NSLog(@"Error creating directory %@", [_url path]);
      [self release];
      return nil;
    }
  }
  else if (exists && !isDirectory)
  {
    NSLog(@"Error, store path %@ is a file.", [_url path]);
    [self release];
    return nil;
  }
  
  return self;
}
+ (COStore *)storeWithURL: (NSURL *)url
{
  return [[[COStore alloc] initWithURL: url] autorelease];
}


- (NSData *)dataForKey: (NSString *)key;
{
  return [NSData dataWithContentsOfFile:
    [[_url path] stringByAppendingPathComponent: key]]; // zlibDecompressed];
}
- (BOOL)setData: (NSData *)data forKey: (NSString *)key;
{
  NSString *path = [[_url path] stringByAppendingPathComponent: key];
  NSLog(@"Saving in '%@'", path);
  
  [data writeToFile: path atomically: YES]; // zlibCompressed]
  return YES;
}
- (void)removeDataForKey: (NSString *)key
{
  if (![[NSFileManager defaultManager]
   removeItemAtPath: [[_url path] stringByAppendingPathComponent: key]
     error: NULL])
  {
    NSLog(@"Removing %@ failed!", key);
  } else {
    NSLog(@"Removed %@", key);
  }
}

@end
