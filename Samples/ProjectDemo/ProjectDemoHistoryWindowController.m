/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  March 2014
    License:  MIT  (see COPYING)
 */

#import "ProjectDemoHistoryWindowController.h"

@interface ProjectDemoHistoryWindowController ()

@end

@implementation ProjectDemoHistoryWindowController

- (NSString *)windowNibName
{
    return @"ProjectDemoHistory";
}

- (id)          tableView: (NSTableView *)tableView
objectValueForTableColumn: (NSTableColumn *)tableColumn
                      row: (NSInteger)row
{
    id <COTrackNode> node = [graphRenderer revisionAtIndex: row];
    if ([[tableColumn identifier] isEqualToString: @"user"])
    {
        return node.metadata[@"username"];
    }
    return [super tableView: tableView objectValueForTableColumn: tableColumn row: row];
}

- (NSDictionary *)customRevisionMetadata
{
    return @{@"username": NSFullUserName()};
}

@end
