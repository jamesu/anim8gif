//
//  DataLoader.h
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

#import <UIKit/UIKit.h>

@interface DataLoader : NSObject {
    NSMutableData *_receivedData;

    // When loading gifs...
    bool detectedVideo; // checked for video data in data stream?
    int videoType;
    bool needData; // do we need this data?
    NSURLConnection *currentConnection;
    
    id _delegate;
}

@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, readonly) bool detectedVideo;
@property (nonatomic, readonly) bool needData;
@property (nonatomic, readonly) int videoType;

+ (DataLoader*)initWithURL:(NSURL*)theURL delegate:(id)del;
- (void)cancel;
- (void)ignoreData;

@end
