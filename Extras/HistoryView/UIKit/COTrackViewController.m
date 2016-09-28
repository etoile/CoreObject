/*
    Copyright (C) 2015 Quentin Mathe

    Date:  January 2015
    License:  MIT  (see COPYING)
 */

#import "COTrackViewController.h"
#import "COTrack.h"

@implementation COTrackViewController

@synthesize track = _track, pastColor = _pastColor, futureColor = _futureColor;


#pragma mark - Initialization -


- (void)setUp
{
    _pastColor = [UIColor darkGrayColor];
    _futureColor = [UIColor lightGrayColor];
}

- (instancetype)initWithNibName: (NSString *)nibName bundle: (NSBundle *)nibBundle
{
    self = [super initWithNibName: nibName bundle: nibBundle];
    if (self == nil)
        return nil;

    [self setUp];
    return self;
}

- (instancetype)initWithCoder: (NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (self == nil)
        return nil;

    [self setUp];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


#pragma mark - Accessing Track and Nodes -


- (void)setTrack: (id <COTrack>)aTrack
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: ETCollectionDidUpdateNotification
                                                  object: _track];
    _track = aTrack;
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(trackDidUpdate:)
                                                 name: ETCollectionDidUpdateNotification
                                               object: aTrack];

    [self trackDidUpdate: nil];
}

- (id <COTrackNode>)nodeForRowAtIndexPath: (NSIndexPath *)indexPath
{
    NSArray *nodes = self.track.nodes;
    NSInteger reversedIndex = nodes.count - 1 - indexPath.row;

    return nodes[reversedIndex];
}

- (BOOL)isFutureNode: (id <COTrackNode>)aNode
{
    NILARG_EXCEPTION_TEST(aNode);

    id <COTrackNode> currentNode = self.track.currentNode;
    ETAssert(currentNode != nil);
    BOOL isFuture = NO;

    for (id <COTrackNode> node in self.track.nodes)
    {
        if ([aNode isEqual: node])
        {
            return isFuture;
        }
        if ([node isEqual: currentNode])
        {
            isFuture = YES;
        }
    }
    ETAssertUnreachable();
    return NO;
}


#pragma mark - Customizing Appearance -


- (UIColor *)suggestedColorForNode: (id <COTrackNode>)node
{
    return ([self isFutureNode: node] ? self.futureColor : self.pastColor);
}

- (UITableViewCell *)makeCellForNode: (id <COTrackNode>)node
{
    static NSString *TrackCellIdentifier = @"TrackCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier: TrackCellIdentifier];

    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault
                                      reuseIdentifier: TrackCellIdentifier];
    }

    cell.textLabel.text = node.localizedShortDescription;
    cell.textLabel.textColor = [self suggestedColorForNode: node];

    return cell;
}

- (void)checkRow: (UITableViewCell *)cell
{
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)uncheckRow: (UITableViewCell *)cell
{
    if (cell.accessoryType != UITableViewCellAccessoryCheckmark)
        return;

    cell.accessoryType = UITableViewCellAccessoryNone;
}


#pragma mark - Reacting to Track Changes -


- (void)trackDidUpdate: (NSNotification *)notif
{
    [self.tableView reloadData];
}


#pragma mark - Actions -


- (IBAction)undo
{
    [self.track undo];
}

- (IBAction)redo
{
    [self.track redo];
}

- (void)didSelectNode: (id <COTrackNode>)aNode
{
    [self.track setCurrentNode: aNode];
}


#pragma mark - Table View Data Source -


- (NSInteger)tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section
{
    return self.track.count;
}

- (UITableViewCell *)tableView: (UITableView *)tableView
         cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
    ETAssert(self.tableView == tableView);
    id <COTrackNode> node = [self nodeForRowAtIndexPath: indexPath];
    UITableViewCell *cell = [self makeCellForNode: node];

    if ([[self.track currentNode] isEqual: node])
    {
        [self checkRow: cell];
    }
    else
    {
        [self uncheckRow: cell];
    }

    return cell;
}

- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
    [self uncheckRow: [tableView cellForRowAtIndexPath: _checkedIndexPath]];
    [self checkRow: [tableView cellForRowAtIndexPath: indexPath]];
    _checkedIndexPath = indexPath;

    [self.tableView deselectRowAtIndexPath: indexPath
                                  animated: NO];

    /* Will trigger -trackDidUpdate: */
    [self didSelectNode: [self nodeForRowAtIndexPath: indexPath]];
}

@end
