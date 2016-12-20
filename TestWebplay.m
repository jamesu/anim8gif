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
//

#import "TestWebplay.h"

@implementation WebplayTest


- (NSString*)applicationDocumentsDirectory
{
    NSArray* ret = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [ret lastObject];
}

- (void)defaultState
{
    [NSUserDefaults resetStandardUserDefaults];
    NSURL *storeURL = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @".data_store.sqlite"]];
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
}

- (void)testDBConvert
{
    [self defaultState];
    
    webplayAppDelegate *delegate = [[webplayAppDelegate alloc] init];
    delegate.config = [NSUserDefaults standardUserDefaults];
    
    NSString *docsDir = [delegate applicationBundleDirectory];
    NSString *path = [docsDir stringByAppendingString:@"/test-anim8gif.sqlite3"];
    [AnimInfo convertOldBookmarksFromLocation:path withDelegate:delegate];
    
    BOOL didCheck = [delegate.config boolForKey:@"didCheckOldDB"];
    STAssertTrue([delegate.config integerForKey:@"lastAnimInfoPK"] == 8, @"Should have processed all records");
    STAssertTrue(didCheck == YES, @"Should have found old DB");
    
    
    NSArray *bkInfos = [delegate fetchRecordsWithOffset:0 andLimit:25 didBookmark:nil didSync:nil ordered:0];
    NSArray *plInfos = [delegate fetchRecordsWithOffset:0 andLimit:25 didBookmark:nil didSync:nil ordered:0];
    
    STAssertTrue([bkInfos count] == 2, @"Should have grabbed all old bookmarks");
    STAssertTrue([plInfos count] == 5, @"Should have grabbed all old played infos");
    
    [delegate release];
}

@end
