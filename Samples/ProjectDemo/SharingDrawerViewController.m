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
    
    NSString *bareJid = [[controller.xmppStream myJID] bare];
    [xmppAccountLabel setStringValue: bareJid != nil ? bareJid : @""];
}

- (void)xmppRosterDidChange:(XMPPRosterMemoryStorage *)sender
{
    users = [sender sortedUsersByAvailabilityName];
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
        SharingSession *session = [controller sharingSessionForBranch: parent.editingBranch];
                
        if ([session isJIDClient: [user jid]])
        {
            [buttonCell setTitle: @"Disconnect"];
            [buttonCell setTarget: self];
            [buttonCell setAction: @selector(disconnect:)];
            [buttonCell setEnabled: YES];
        }
        else
        {
            if ([user isOnline])
            {
                [buttonCell setTitle: @"Invite"];
                [buttonCell setTarget: self];
                [buttonCell setAction: @selector(invite:)];
                [buttonCell setEnabled: YES];
            }
            else
            {
                [buttonCell setTitle: @"Offline"];
                [buttonCell setEnabled: NO];
            }
        }
    }
}

- (void)disconnect: (id)sender
{
    id<XMPPUser> user = [users objectAtIndex: [table clickedRow]];
    NSLog(@"TODO: Disconnect %@", [user jid]);
}

- (void)invite: (id)sender
{
    id<XMPPUser> user = [users objectAtIndex: [table clickedRow]];
    
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
        return [NSString stringWithFormat: @"%@ (%@)", [user nickname], [[user jid] bare]];
    }
    return nil;
}
- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    

}

@end
