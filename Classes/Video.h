//
//  Video.h
//  template
//
//  Created by James Urquhart on 27/02/2009.
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

#import <Foundation/Foundation.h>

#import "VideoTexture.h"
#import "VideoSource.h"
#import "VideoWorker.h"

#define MAX_CACHE 2

#define VIDEO_NONE 0 // data
#define VIDEO_GIF  1
#define VIDEO_PNG  2
#define VIDEO_WEBM 3

typedef struct TargetRenderInfo
{
   GLuint frameBuffer;
   GIFRect viewport;
   GLfloat projection[16];
} TargetRenderInfo;


static inline TargetRenderInfo TargetRenderInfoMake(GLuint frameBuffer, GIFRect viewport, GLfloat* newProjection) { TargetRenderInfo info; info.frameBuffer = frameBuffer; info.viewport = viewport; memcpy(info.projection, newProjection, sizeof(GLfloat)*16); return info; }

void TargetRenderInfoSet(TargetRenderInfo info);

@class EAGLContext;
@class PlayerView;

@interface Video : NSObject {
    VideoSource *src;
    
    EAGLContext *context;
    
    int width;
    int height;
    int bpp;
    
    GLint fmt;
    
    int req_pos;
    int upload_size;
    
    double fps_time;
    
    // state
    bool playing;
    bool loop;
    int v_frame; // read frame
    
    id thumbDelegate;
    id thumbObject;
    NSTimeInterval thumbTime;
   
    TargetRenderInfo viewRenderInfo;
    TargetRenderInfo disposalRenderInfo;
   
   
    VideoTexture *painter;
    GLuint framebuffer, texture;
    VideoWorkerFrame_t last_frame;
}


@property(nonatomic, assign) TargetRenderInfo viewRenderInfo;
@property(nonatomic, readonly) int upload_size;
@property(nonatomic, readonly) double fps_time;
@property(nonatomic, readonly) GLint fmt;
@property(nonatomic, retain) id thumbDelegate;
@property(nonatomic, assign) NSTimeInterval thumbTime;
@property(nonatomic, retain) id thumbObject;
@property(nonatomic, readonly, assign) bool playing;
@property(nonatomic, assign) VideoSource *src;
@property(nonatomic, readonly) int videoType;

- (void)play:(bool)doesLoop;
- (void)stop;

- (bool)setupRenderTexture;
- (void)clearRenderTexture;
- (void)setPaintHead:(VideoTexture*)painter;

// Overrides
- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx;
- (bool)nextFrame:(unsigned char*)data withDt:(float*)dt;
- (void)resetState:(bool)gl;
- (void)frameClipScale:(float*)scale;
- (CGSize)frameSize;
- (CGSize)backingSize;
- (bool)drawNextFrame:(float)dt toView:(PlayerView*)view fromWorker:(VideoWorker*)worker withBackingSize:(CGSize)size;

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal;
- (void)drawPreviousFrame:(GIFRect)frameRect;

- (UIImage*)dumpFrame:(VideoWorkerFrame_t*)frame;

+ (Video*)videoByType:(int)type withSource:(VideoSource*)source inContext:(EAGLContext*)context;

@end



extern GLfloat sVidSquareVertices[8];
extern GLfloat sVidSquareTexcoords[8];
