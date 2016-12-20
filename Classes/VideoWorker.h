//
//  VideoWorker.h
//  webplay
//
//  Created by James Urquhart on 12/09/2010.
//
// (C) James S Urquhart 2010 - 2016
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

#import <Foundation/Foundation.h>

#define DISPOSE_RESET 0
#define DISPOSE_CLEARBG 1
#define DISPOSE_PREVIOUSBG 2
#define DISPOSE_NONE 3

#define BLEND_SOURCE 0
#define BLEND_OVER 1

@class Video;

typedef struct GIFRect
{
   int x, y, width, height;
} GIFRect;

static inline GIFRect GIFRectMake(int x, int y, int w, int h) { GIFRect rect; rect.x = x; rect.y = y; rect.width=w; rect.height=h; return rect; }

typedef struct VideoWorkerFrame_s {
    char disposal_type, blend_type;
    unsigned char *data;
   
    float dt;
    bool ready;
    bool reset;
   
    int frameID;
   
    GIFRect rect;
   char clear_r, clear_g, clear_b, clear_a;
} VideoWorkerFrame_t;

@interface VideoWorker : NSObject {
    NSThread *thread;
    id target;
    
    int dataSize;
    
    VideoWorkerFrame_t *frames;
    
    VideoWorkerFrame_t *nextView; // View which will be shown
    VideoWorkerFrame_t *backView; // View which will be shows after nextView
    
    float trackDt;
   float waitDt;
    
    NSLock *frameLock;
}

@property(nonatomic, readonly) NSLock *frameLock;
@property(nonatomic, readonly) NSThread *thread;


- (id)initWithVideo:(Video*)theVideo andTarget:(id)target;
- (VideoWorkerFrame_t*)getFrame:(float)dt; // null == no change
- (void)start;
- (void)stop;

- (VideoWorkerFrame_t)getFreeFrame;
- (void)pushNewFrame:(VideoWorkerFrame_t)frame;

@end
