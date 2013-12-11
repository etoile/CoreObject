#import "SharingDrawerViewController.h"
#import "XMPPController.h"
#import "XMPPFramework.h"

@interface SharingDrawerViewController ()

@end

@implementation SharingDrawerViewController

- (id)init
{
    self = [super initWithNibName: @"SharingDrawer" bundle: nil];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib
{
	[[[XMPPController sharedInstance] roster] addDelegate: self delegateQueue: dispatch_get_main_queue()];
	[self xmppRosterDidChange: (XMPPRosterMemoryStorage *)[[[XMPPController sharedInstance] roster] xmppRosterStorage]];
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
	users = [sender sortedAvailableUsersByName];
	[table reloadData];
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [users count];;
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id<XMPPUser> user = [users objectAtIndex: row];
	
    if ([[tableColumn identifier] isEqual: @"user"])
    {
        return [[user jid] bare];
    }
    else if ([[tableColumn identifier] isEqual: @"button"])
    {
        return @"hello";
    }
    return nil;
}
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	

}

@end
