//
//  PlayerView.h
//  webplay
//
//  Created by James Urquhart on 16/02/2009.
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

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "VideoTexture.h"
#import "VideoSource.h"
#import "VideoWorker.h"

@class VideoWorker;
@class Video;
#define PLAYER_DEG_TO_RAD				0.017453f

@interface PlayerView : UIControl {
    
@private
    /* The pixel dimensions of the backbuffer */
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint viewRenderbuffer, viewFramebuffer;
   
    GLfloat projectionMatrix[16];

    
@public
    UIInterfaceOrientation targetOrient;
    bool isSlaveView;
    
    float rot;
    
    float d_rot;
    float d_sx;
    float d_sy;
    float sx; // current scale x
    float sy; // current scale y
    float t_sx; // target scale x
    float t_sy; // target scale y
    float t_rot;
    
    float tex_sx;
    float tex_sy;
    
    bool madeFB;
    
    bool gotVideoFrame;
    bool zoomAspect;
    bool isSlave;

    Video *video;
    VideoWorker *worker;
}

@property(nonatomic, assign) bool gotVideoFrame;
@property(nonatomic, assign) UIInterfaceOrientation targetOrient;
@property(nonatomic, retain) Video *video;
@property(nonatomic, assign) VideoWorker *worker;
@property(nonatomic, assign) bool zoomAspect;
@property(nonatomic, assign) bool isSlave;

@property(nonatomic, retain) EAGLContext *context;

- (id)initWithFrame:(CGRect)frame inShareGroup:(void*)glShare;
- (void)drawView:(float)dt;
- (void)clearView;

- (void)setViewBuffer;

- (void)setAspectScale:(bool)force;
- (void)clearAspectScale;


@end
