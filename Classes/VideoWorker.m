//
//  VideoWorker.m
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

#define FRAME_COUNT 2

#import "VideoWorker.h"
#import "webplayAppDelegate.h"
#import "Video.h"

@implementation VideoWorker

@synthesize frameLock;
@synthesize thread;

- (id)initWithVideo:(Video*)theVideo andTarget:(id)theTarget {
    if (self = [super init]) {
        frames = malloc(sizeof(VideoWorkerFrame_t) * FRAME_COUNT);
        if (!frames)
            return NULL;
       
        int size = theVideo.upload_size;
        
        for (int i=0; i<FRAME_COUNT; i++) {
            frames[i].data = malloc(size);
            frames[i].ready = false;
        }
        
        trackDt = 0.0;
        nextView = NULL;
        backView = NULL;
       waitDt=0;
        
        target = theTarget;
        thread = nil;
        
        frameLock = [[NSLock alloc] init]; 
        
        L0Log(@"WORKER: created with target %x", target);
    }
    
    return self;
}

static void tSleep(uint32_t ms)
{
    struct timeval tv;
	uint32_t microsecs = ms * 1000;
    
	tv.tv_sec  = microsecs / 1000000;
	tv.tv_usec = microsecs % 1000000;
    
	select( 0, NULL, NULL, NULL, &tv );	
}


- (VideoWorkerFrame_t*)getFrame:(float)dt
{
    VideoWorkerFrame_t *res = NULL;
    trackDt += dt;
    if (nextView && (trackDt <= 0 || trackDt >= waitDt)) {
        // Frame is present and ready
        [frameLock lock];
        res = nextView;
        nextView = backView;
        backView = NULL;
        [frameLock unlock];
        
        //L0Log(@"trackDt == %f, dt == %f", trackDt, dt);
        trackDt = 0;
        waitDt = res ? res->dt : 0;
        //trackDt = trackDt > 1.0 ? res->dt : res->dt*trackDt;
    }
    return res;
}

- (void)doWork:(id)object {
    NSAutoreleasePool	*pool;
    NSThread *thr = thread;
    NSLock *theLock = frameLock;
    
    [object retain];
    [theLock retain];
    
    while (![thr isCancelled])
    {
        //L0Log(@"WORKER: alive");
        pool = [[NSAutoreleasePool alloc] init];
        bool processed = false;
       
        if (((Video*)object).playing)
        {        
           VideoWorkerFrame_t freeFrame = [self getFreeFrame];
           if (freeFrame.data) {
               processed = [object nextFrame:&freeFrame];
               if (processed) {
                   //L0Log(@"WORKER: pushed frame");
                   [self pushNewFrame:freeFrame];
               }
           }
        }
        
        [pool release];
        tSleep(processed ? 1 : 10);
    }
    
    L0Log(@"WORKER: killed");
    
    [object release];
    [theLock release];
}

- (VideoWorkerFrame_t)getFreeFrame {
    // NOTE: no locking needed here, we are not writing
    for (int i=0; i<FRAME_COUNT; i++) {
        if (!frames[i].ready)
            return frames[i];
    }
    
    VideoWorkerFrame_t frame;
    frame.data = NULL;
    return frame;
}

- (void)pushNewFrame:(VideoWorkerFrame_t)frame {
    // NOTE: lock needed since we are writing
    [frameLock lock];
    int i = 0;
    for (i=0; i<FRAME_COUNT; i++) {
        if (frames[i].data == frame.data) {
            frames[i] = frame;
            frames[i].ready = true;
            break;
        }
    }
    if (i == FRAME_COUNT) {
        [frameLock unlock];
        return; // ???!!
    }
    
    if (nextView == NULL)
        nextView = frames+i;
    else if (backView == NULL)
        backView = frames+i;
    
    [frameLock unlock];
}

- (void)dealloc {
    // NOTE: by the time this happens, all threads will have stopped
    
    for (int i=0; i<FRAME_COUNT; i++) {
        if (frames[i].data)
            free(frames[i].data);
    }
    free(frames);
    [frameLock release];
    
    L0Log(@"Worker killed");
    L0LogIf(thread, @"WARNING: VideoWorker freed with running thread!");
    
    [super dealloc];
}

- (void)start {
    if (thread)
        return;
    
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(doWork:) object:target];
    [thread start];
}

- (void)stop {
    if (thread) {
        if ([thread isExecuting])
            [thread cancel];
        [thread release];
        thread = nil;
    }
}

@end
