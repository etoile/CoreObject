#import "ObjectMergingAppDelegate.h"
#import "COArrayDiff.h"
#import "COStringDiff.h"
#import "COStore.h"
#import "COSerializer.h"
#import "COObject.h"
#import "COObjectContext.h"
#import "NSData+sha1.h"
#import "NSData+compression.h"

#define STORE_URL [NSURL URLWithString: [@"~/ObjectMergingTestStore" stringByExpandingTildeInPath]]

/**
 * Test application. FIXME: create proper UnitKit tests.
 */
@implementation ObjectMergingAppDelegate

@synthesize window;

- (void) testArrayDiffMerge
{
  NSArray *array = [NSArray arrayWithObjects:
    @"a", @"b", @"c", @"d", @"e", @"f", nil
    ];
  NSArray *array2 = [NSArray arrayWithObjects:
    @"A", @"c", @"d", @"zoo", @"e", nil
    ];

  NSArray *array3 = [NSArray arrayWithObjects:
    @"A", @"b", @"c", @"e", @"foo", nil
    ];

  COArrayDiff *diff = [[COArrayDiff alloc] initWithFirstArray: array secondArray: array2];
  
  // Test diff application
  {
    NSLog(@"before applying: %@", array);
    NSLog(@"after applying: %@", [diff arrayWithDiffAppliedTo: array]);
  }
  
  // Test 3 way merge of arrays.
  
  COArrayDiff *diff13 = [[COArrayDiff alloc] initWithFirstArray: array secondArray: array3];
  COMergeResult *merge = [diff mergeWith: diff13];
            
  NSLog(@"3-way merge results:");
  
  NSLog(@"Nonoverlapping nonconflicting:");
  for (NSObject *op in [merge nonoverlappingNonconflictingOps])
  {
    NSLog(@"op: %@", op);
  }
  NSLog(@"Overlapping nonconflicting:");
  for (NSObject *op in [merge overlappingNonconflictingOps])
  {
    NSLog(@"op: %@", op);
  }

  NSLog(@"Expected: a->A, remove b, delete d, insert 'zoo' after d, insert foo after e");
}

- (void) testHash
{
  char *str = "The quick brown fox jumps over the lazy dog";

  assert([[[NSData dataWithBytes:str length:strlen(str)] sha1HashHexString] 
    isEqualToString: @"2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"]);
    
  assert([[[NSData data] sha1HashHexString]
    isEqualToString: @"da39a3ee5e6b4b0d3255bfef95601890afd80709"]);
  
  assert([[[NSData data] sha1Hash] isEqual: 
          [NSData dataWithHexString: @"da39a3ee5e6b4b0d3255bfef95601890afd80709"]]);
  
  NSLog(@"Hash works");
}


- (void) testCompression
{
  NSString *string = @"Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me! Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me!";
  
  const char *bytes = [string UTF8String];
  NSData *uncompressed = [NSData dataWithBytes: bytes
                                        length: strlen(bytes)];
 
  NSData *compressed = [uncompressed zlibCompressed];
  
  assert([compressed length] < [uncompressed length]);
  NSLog(@"Compressed %d uncompresesd %d", [compressed length], [uncompressed length]);

  NSData *decompressed = [compressed zlibDecompressed];
  
  assert([uncompressed isEqualToData: decompressed]);
  NSLog(@"Compression worked OK");
  
  assert([[NSData data] zlibCompressed] != nil);
  assert([[[[NSData data] zlibCompressed] zlibDecompressed]
              isEqualToData: [NSData data]]);
}

- (void) testSerialization
{
  NSArray *sample = [NSArray arrayWithObjects: @"Hello", @"There", nil];
  assert([[COSerializer unserializeData: [COSerializer serializeObject: sample]] isEqual: sample]);
  NSLog(@"Serialization works");
}


- (void) testDiffVisualization
{
  NSString *orig = @"Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me! Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me!";
  NSString *branch1 = @"Demons and minions of terror defend us! Be thou a spirit of health or goblin damn'd, Be thy intents wicked or charitable, Bring with thee airs from heaven or blasts from hell, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me! Angels and ministers of grace defend us! Be thou a spirit of health or goblin damn'd, Bring with thee airs from heaven or blasts from hell, Be thy intents wicked or charitable, Thou comest in such a questionable shape That I will speak to thee: I'll call thee Hamlet, King, father, royal Dane: O, answer me! String Diff example. Note this is just doing LCS on characters of strings, which is why the output is a big ugly. I'm going to try better algorithms.. See the NOTES file.";
  
  [textView insertText: [[[COStringDiff alloc] initWithFirstString: orig secondString: branch1] attributedStringWithDiffAppliedTo: orig]];
}

- (void)testBasicAPI
{
  NSLog(@"Testing basic API");
  
  COStoreCoordinator *sc = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
  
  COObjectContext *ctx = [[COObjectContext alloc] initWithStoreCoordinator: sc];
  COObject *obj1 = [[COObject alloc] initWithContext:ctx];
  [obj1 setValue: @"Necronomicon" forProperty: @"title"];
  [obj1 setValue: @"Abdhul Al-hazred" forProperty: @"author"];
  
  COObject *obj2 = [[COObject alloc] initWithContext:ctx];
  [obj2 setValue: @"The King in Yellow" forProperty: @"title"];
  [obj2 setValue: @"Robert W. Chambers" forProperty: @"author"];
  [obj2 setValue: S(@"H.P. Lovecraft", @"Eric Wasylishen") forProperty: @"lent-to"];
  
  [ctx commit];
  
  [obj2 setValue: @"???" forProperty: @"author"];
  [obj2 setValue: S(@"H.P. Lovecraft") forProperty: @"lent-to"];
  
  [ctx commit];
  
  [ctx release];
  [sc release];
  
  
  NSLog(@"Reopening store..");  
  COStoreCoordinator *sc2 = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
  COObjectContext *ctx2 = [[COObjectContext alloc] initWithHistoryGraphNode: [sc2 tip]];
  NSLog(@"Previous tip revision is: %@", [ctx2 baseHistoryGraphNode]);  

  for (ETUUID *uuid in [[[ctx2 baseHistoryGraphNode] uuidToObjectVersionMaping] allKeys])
  {
    [[ctx2 objectForUUID: uuid] loadIfNeeded];
    NSLog(@"Modified in tip: UUID: %@, Object %@", uuid, [ctx2 objectForUUID: uuid]);
  }
  
  NSLog(@"Testing object graph diff");
  NSLog(@"%@", [COObjectGraphDiff diffObject: obj1 with: obj2]);
  
  NSLog(@"Basic API works");
}

- (void) testObjectMerging
{
  NSLog(@"Testing object merging");
    
  COObjectContext *ctx = [[COObjectContext alloc] init];
  COObject *obj1 = [[COObject alloc] initWithContext:ctx];
  [obj1 setValue: @"Necronomicon" forProperty: @"title"];
  [obj1 setValue: @"Abdhul Al-hazred" forProperty: @"author"];
  [obj1 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen") forProperty: @"readers"];
  
  COObject *obj2 = [[COObject alloc] initWithContext:ctx];
  [obj2 setValue: @"The King in Yellow" forProperty: @"title"];
  [obj2 setValue: A(@"Eric Wasylishen") forProperty: @"readers"];
  
  COObject *obj3 = [[COObject alloc] initWithContext:ctx];
  [obj3 setValue: @"The King in Blue" forProperty: @"title"];
  [obj3 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen", @"Tolkien") forProperty: @"readers"];
  
  COObjectGraphDiff *oa = [COObjectGraphDiff diffObject: obj1 with: obj2];
  COObjectGraphDiff *ob = [COObjectGraphDiff diffObject: obj1 with: obj3];
  COObjectGraphDiff *merged = [COObjectGraphDiff mergeDiff: oa withDiff: ob];
  
  NSLog(@"O-A diff: %@", oa);
  NSLog(@"O-B diff: %@", ob);
  NSLog(@"Merged diff: %@", merged);  
  
  [merged applyToContext:ctx];
  
  NSLog(@"Merged object:%@", obj1);
  
  NSLog(@"Obejct merging works");

  
  [ctx release];
}

- (void) testObjectComposition
{
  NSLog(@"Testing object composition");
  ETUUID *libraryUUID;
  
  {
    COStoreCoordinator *sc = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
    COObjectContext *ctx = [[COObjectContext alloc] initWithStoreCoordinator: sc];
    
    COObject *book1 = [[COObject alloc] initWithContext:ctx];
    [book1 setValue: @"The King in Yellow" forProperty: @"title"];
    [book1 setValue: A(@"Eric Wasylishen") forProperty: @"readers"];  

    COObject *book2 = [[COObject alloc] initWithContext:ctx];
    [book2 setValue: @"The King in Blue" forProperty: @"title"];
    [book2 setValue: A(@"H.P. Lovecraft", @"Eric Wasylishen", @"Tolkien") forProperty: @"readers"];

    COObject *obj1 = [[COObject alloc] initWithContext:ctx];
    [obj1 setValue: @"Arkham Public Library" forProperty: @"name"];
    [obj1 setValue: A(book1, book2) forProperty: @"books"];
    libraryUUID = [obj1 uuid];
    
    NSLog(@"obj1 %@", obj1);
    
    [ctx commit];
    
    [ctx release];
    [sc release];
  }
  
  NSLog(@"Reopening store..");  
  {
    COStoreCoordinator *sc2 = [[COStoreCoordinator alloc] initWithURL: STORE_URL];
    COObjectContext *ctx2 = [[COObjectContext alloc] initWithHistoryGraphNode: [sc2 tip]];
    COObject *library = [ctx2 objectForUUID: libraryUUID];
    NSLog(@"Library (reopened): %@", library);
    
    assert([library isFault]);
    assert([[library valueForProperty: @"name"] isEqual: @"Arkham Public Library"]);
    assert(![library isFault]);
    
    COObject *book1 = [[library valueForProperty: @"books"] objectAtIndex: 0];
    COObject *book2 = [[library valueForProperty: @"books"] objectAtIndex: 1];

    NSLog(@"Book1 %@ Book2 %@", book1, book2);
    
    assert([book1 isFault]);
    assert([book2 isFault]);
    assert([[book1 valueForProperty: @"title"] isEqual: @"The King in Yellow"]);
    
    [sc2 release];
    [ctx2 release];
  }
  NSLog(@"Testing object composition success");
}

- (void) awakeFromNib
{
  [self testArrayDiffMerge];
  [self testCompression];
  [self testHash];
  [self testSerialization];
  [self testDiffVisualization];  
  [self testBasicAPI];
  [self testObjectMerging];
  [self testObjectComposition];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

}

@end
