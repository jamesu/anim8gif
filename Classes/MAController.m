//
//  MAController.m
//  webplay
//
//  Created by James Urquhart on 28/05/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MAController.h"
#import "CDAnimInfo.h"
#import "webplayAppDelegate.h"

@implementation MAController

- (id)init
{
    if (self = [super init]) {
        webplayAppDelegate *app = (webplayAppDelegate*)[[UIApplication sharedApplication] delegate];
        NSUserDefaults *config = app.config;
        
        date = [[config objectForKey:@"MATime"] retain];
        _receivedData = nil;
    }
    
    return self;
}

- (void)dealloc
{
    [self cancel];
    [date release];
    [super dealloc];
}

- (void)cancel
{
    [_receivedData release];
    _receivedData = nil;
    
    if (_currentConnection) {
        [_currentConnection cancel];
        [_currentConnection release];
        _currentConnection = nil;
    }
}

- (void)scan
{
    NSDate *now = [NSDate date];
    if ([date timeIntervalSinceDate:now] > (60*60*24)) {
        webplayAppDelegate *app = (webplayAppDelegate*)[[UIApplication sharedApplication] delegate];
        NSUserDefaults *config = app.config;
        
        // Set new time
        [config setObject:now forKey:@"MATime"];
        
        // Load ads...
        NSURL *url = [NSURL URLWithString:@"http://www.jamesu.net/ads/anim8gif.txt"];
        NSURLRequest *req = [NSURLRequest requestWithURL:url];
        
        if (_currentConnection)
            [self cancel];
        
        _currentConnection = [NSURLConnection connectionWithRequest:req delegate:self];
        
        if (req) {
            L0Log(@"Ads connection ok...");
            _receivedData = [[NSMutableData data] retain];
            [_currentConnection retain];
        } else {
            L0Log(@"Error!");
        }
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_receivedData == nil) {
        [self cancel];
        return;
    }
    
    //L0Log(@"Processing %i bytes", [data length]);
    
    [_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error
{
    // We're finished!
    [self cancel];
	
    // inform the user
    L0Log(@"Ad Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (_receivedData == nil) {
        [self cancel];
        return;
    }
    
    [_receivedData setLength:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_receivedData == nil) {
        [_currentConnection release];
        _currentConnection = nil;
        return;
    }
    
	// do something with the data
    // receivedData is declared as a method instance elsewhere
    L0Log(@"Ad Succeeded! Received %d bytes of data",[_receivedData length]);
    
    // Load into bookmarks
    NSPropertyListFormat format;
    NSString *errorDesc = nil;
    NSDictionary *temp = (NSDictionary *)[NSPropertyListSerialization
                                          propertyListFromData:_receivedData
                                          mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                          format:&format errorDescription:&errorDesc];
    
    webplayAppDelegate *app = (webplayAppDelegate*)[[UIApplication sharedApplication] delegate];
    NSUserDefaults *config = app.config;
    
    if (temp) {
        // Ok, got property list!
        webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
        
        NSArray *adList = [temp objectForKey:@"AdList"];
        for (NSDictionary *item in adList) {
            // URL and 
            
            NSURL *url = [NSURL URLWithString:[item objectForKey:@"url"]];
            NSDate *postDate = [item objectForKey:@"date"];
            
            L0Log(@"URL %@ with date %@", url, postDate);
            
            // item was added *after* LAST check?
            if (url && postDate && (date == nil || [postDate timeIntervalSinceDate:date] > 0)) {
                // Add to list
                CDAnimInfo *anim = (CDAnimInfo*)[NSEntityDescription insertNewObjectForEntityForName:@"AnimInfo"
                                                                              inManagedObjectContext:[del managedObjectContext]] ;
                anim.url = [url absoluteString];
                anim.dontShow = [NSNumber numberWithBool:NO];
                anim.isLink = [item objectForKey:@"link"];
                anim.didBookmark = [NSNumber numberWithBool:YES];
                
                
                [del saveContext];
                [anim release];
            }
        }
    }
    
    // Set new time
    [date release];
    date = [config objectForKey:@"MATime"];
    [date retain];
    
    [_receivedData release];
        
    [_currentConnection release];
    _currentConnection = nil;
}


@end
