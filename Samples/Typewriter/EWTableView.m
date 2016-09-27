/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  March 2014
    License:  MIT  (see COPYING)
 */

#import "EWTableView.h"

@implementation EWTableView

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    NSMenu *menu = [super menuForEvent: event];
    
    if ([[self delegate] respondsToSelector: @selector(tableView:menuForEvent:defaultMenu:)])
    {
        menu = [(id<EWTableViewDelegate>)[self delegate] tableView: self menuForEvent: event defaultMenu: menu];
    }
    
    return menu;
}

@end
