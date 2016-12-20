//
//  MAController.h
//  webplay
//
//  Created by James Urquhart on 28/05/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MAController : NSObject {
    NSDate *date;
    
    NSMutableData * _receivedData;
    NSURLConnection *_currentConnection;
}

- (void)cancel;
- (void)scan;

@end
