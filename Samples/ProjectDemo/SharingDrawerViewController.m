#import "SharingDrawerViewController.h"
#import "XMPPController.h"
#import "XMPPFramework.h"
#import "EWDocumentWindowController.h"

@interface SharingDrawerViewController ()

@end

@implementation SharingDrawerViewController

- (id)initWithParent: (EWDocumentWindowController *)aParent
{
    self = [super initWithNibName: @"SharingDrawer" bundle: nil];
    if (self) {
        parent = aParent;
    }
    return self;
}

- (void)awakeFromNib
{
	XMPPController *controller = [XMPPController sharedInstance];
	
	[[controller roster] addDelegate: self delegateQueue: dispatch_get_main_queue()];
	[self xmppRosterDidChange: (XMPPRosterMemoryStorage *)[[[XMPPController sharedInstance] roster] xmppRosterStorage]];
	[xmppAccountLabel setStringValue: [[controller.xmppStream myJID] bare]];
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
	users = [sender sortedAvailableUsersByName];
	[table reloadData];
}

/* NSTableViewDelegate */

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id<XMPPUser> user = [users objectAtIndex: row];
	
	if ([[tableColumn identifier] isEqual: @"button"])
    {
		NSButtonCell *buttonCell = cell;
		XMPPController *controller = [XMPPController sharedInstance];
		SharingSession *session = [controller sharingSessionForPersistentRootUUID: [parent.persistentRoot UUID]
																		  fullJID: [[user jid] full]];
		if (session != nil)
		{
			[buttonCell setTitle: @"Disconnect"];
			[buttonCell setTarget: self];
			[buttonCell setAction: @selector(disconnect:)];
		}
		else
		{
			[buttonCell setTitle: @"Invite"];
			[buttonCell setTarget: self];
			[buttonCell setAction: @selector(invite:)];
		}
    }
}

- (void)disconnect: (id)sender
{
	id<XMPPUser> user = [users objectAtIndex: [table clickedRow]];
	
}

- (void)invite: (id)sender
{
	id<XMPPUser> user = [users objectAtIndex: [table clickedRow]];
	ETUUID *aUUID = [parent.persistentRoot UUID];
	
	XMPPController *controller = [XMPPController sharedInstance];
	[controller shareBranch: parent.editingBranch withJID: user.jid];
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
    return nil;
}
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	

}

@end
