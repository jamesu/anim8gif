//
//  DataLoader.m
//  webplay
//
//  Created by James Urquhart on 15/11/2009.
//
// (C) James S Urquhart 2009 - 2016
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "webplayAppDelegate.h"
#import "DataLoader.h"
#import "Video.h"

#include "png.h"

@implementation DataLoader

@synthesize detectedVideo;
@synthesize videoType;
@synthesize receivedData = _receivedData;
@synthesize needData;

- (id)initWithURL:(NSURL*)theURL andDelegate:(id)del
{
    if (self = [super init]) {
        _delegate = [del retain];
        _receivedData = nil;
        detectedVideo = NO;
        videoType = VIDEO_NONE;
        needData = YES;
        
        NSURLRequest *req = [NSURLRequest requestWithURL:theURL];
        if (req) {
            currentConnection = [NSURLConnection connectionWithRequest:req delegate:self];
        
            if (currentConnection) {
                L0Log(@"Connection ok...");
                _receivedData = [[NSMutableData data] retain];
                [currentConnection retain];
            } else {
                L0Log(@"Error!");
                [self release];
                return nil;
            }
        }
    }
    
    return self;
}

+ (DataLoader*)initWithURL:(NSURL *)theURL delegate:(id)del
{
    return [[[DataLoader alloc] initWithURL:theURL andDelegate:del] autorelease];
}

- (void)dealloc
{
    [_delegate release];
    [self cancel];
    [super dealloc];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
    [_delegate setCurrentURL:request.URL];
    return request;
}

- (void)checkDocument
{
    if ([_receivedData length] >= 24) {
        detectedVideo = YES;
        unsigned char buffer[24];
        [_receivedData getBytes:buffer length:24];
        
        if (buffer[0] == 'G' && buffer[1] == 'I' && buffer[2] == 'F')
        {
            videoType = VIDEO_GIF;
            [_delegate performSelector:@selector(onLoaderDetectedDocument:typeName:) withObject:self withObject:@"GIF"];
        }
        else if (png_check_sig(buffer, 8))
        {
           videoType = VIDEO_PNG;
           [_delegate performSelector:@selector(onLoaderDetectedDocument:typeName:) withObject:self withObject:@"PNG"];
        }
        else
        {
            videoType = VIDEO_NONE;
            [_delegate performSelector:@selector(onLoaderDetectedDocument:typeName:) withObject:self withObject:@"DOC"];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_receivedData == nil && needData) {
        [self cancel];
        return;
    }
    
    //L0Log(@"Processing %i bytes", [data length]);
    
    // Check
    if (!detectedVideo && needData)
        [self checkDocument];
    
    [_delegate performSelector:@selector(onLoaderReceivedData:withData:) withObject:self withObject:data];
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error
{
    [_delegate performSelector:@selector(onLoaderFailed:withError:) withObject:self withObject:error];
    
    // debug
    L0Log(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
    
    [self cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (_receivedData == nil && needData) {
        [self cancel];
        return;
    }
    
    if (_receivedData)
        [_receivedData setLength:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_receivedData == nil && needData) {
        [self cancel];
        return;
    }
    
    // Check
    if (!detectedVideo)
        [self checkDocument];
    
	// do something with the data
    // receivedData is declared as a method instance elsewhere
    L0Log(@"Succeeded! Received data.");
    
    [_delegate performSelector:@selector(onLoaderData:) withObject:self];
    
    if (_receivedData) {
        [_receivedData release];
        _receivedData = nil;
    }
    if (currentConnection) {
        [currentConnection release];
        currentConnection = nil;
    }
}


- (void)cancel
{
    if (_receivedData) {
        [_receivedData release];
        _receivedData = nil;
    }
    
    if (currentConnection) {
        [currentConnection cancel];
        [currentConnection release];
        currentConnection = nil;
        
        [_delegate performSelector:@selector(onLoaderCancel:) withObject:self];
    }
}

- (void)ignoreData
{
    [_receivedData release];
    _receivedData = nil;
    needData = NO;
}

@end
