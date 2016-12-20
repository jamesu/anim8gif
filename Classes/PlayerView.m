//
//  PlayerView.m
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

#import "PlayerView.h"

#import "Video.h"
#import "GifVideo.h"
#import "webplayAppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

GLint sMaxTextureSize = 1024;

@implementation PlayerView

@synthesize context;
@synthesize worker;
@dynamic targetOrient;
@dynamic zoomAspect;
@synthesize isSlave;
@synthesize gotVideoFrame;

// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame inShareGroup:nil];
}

- (id)initWithFrame:(CGRect)frame inShareGroup:(void*)glShare {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        targetOrient = UIInterfaceOrientationPortrait;
        isSlaveView = [self class] == [SlavePlayerView class];
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        if (glShare) {
            context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:glShare];
        } else {
            context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        }
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [self release];
            return nil;
        }
        
        sx = 2.0;
        sy = 3.0;
        
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
        rot = 0.0;
        
        tex_sx = 1.0;
        tex_sy = 1.0;
        
        video = NULL;
        worker = NULL;
        
        gotVideoFrame = NO;
        isSlave = NO;
        
        [self layoutSubviews];
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
       
       
        isSlaveView = [self class] == [SlavePlayerView class];
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [self release];
            return nil;
        }
       
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &sMaxTextureSize);
        
        sx = 2.0;
        sy = 3.0;
        
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
        rot = 0.0;
        
        tex_sx = 1.0;
        tex_sy = 1.0;
        
        video = NULL;
        worker = NULL;
        
        gotVideoFrame = NO;
        isSlave = NO;
        
        [self layoutSubviews];
    }
    return self;
}

- (UIInterfaceOrientation)targetOrient
{
    return targetOrient;
}

- (void)setTargetOrient:(UIInterfaceOrientation)target
{
    float scale[2];
    [video frameClipScale:scale];
    tex_sx = scale[0];
    tex_sy = scale[1];
    
    targetOrient = target;
    [self setAspectScale:NO];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

- (void)clearView {
    [EAGLContext setCurrentContext:context];
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    
    glViewport(0, 0, backingWidth, backingHeight);
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
   
   
    
    // TODO
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)drawView:(float)dt {
    // Replace the implementation of this method to do your own custom drawing
    
   [EAGLContext setCurrentContext:context];
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
   
   // Update render info for video
   video.viewRenderInfo = TargetRenderInfoMake(viewFramebuffer, GIFRectMake(0, 0, backingWidth, backingHeight), projectionMatrix);
   
   glViewport(0, 0, backingWidth, backingHeight);
   
   glClearColor(0, 0, 0, 1);
   glClear(GL_COLOR_BUFFER_BIT);
   
   glMatrixMode(GL_PROJECTION);
   glLoadMatrixf(projectionMatrix);
   
   // Flip model view upside down
   glMatrixMode(GL_MODELVIEW);
   glLoadIdentity();
   glTranslatef(0, backingHeight, 0);
   glScalef(1, -1, 1);
   glPushMatrix();
   
   CGSize frameSize = video.frameSize;
    
    // See if we have a frame ready
    
    bool drawn = false;
    //L0Log(@"vid getFrame");
   
   // Rotates on the top left
   
   // Apply content scaling
   
   
   if (sx != t_sx)
   {
      if (d_sx > 0.0) {
         if (sx > t_sx)
            sx = t_sx;
         else
            sx += d_sx;
      } else {
         if (sx < t_sx)
            sx = t_sx;
         else
            sx += d_sx;
      }
   }
   
   if (sy != t_sy)
   {
      if (d_sy > 0.0) {
         if (sy > t_sy)
            sy = t_sy;
         else
            sy += d_sy;
      } else {
         if (sy < t_sy)
            sy = t_sy;
         else
            sy += d_sy;
      }
   }
   
   if (rot != t_rot)
   {
      if (d_rot > 0.0) {
         if (rot > t_rot)
            rot = t_rot;
         else
            rot += d_rot;
      } else {
         if (rot < t_rot)
            rot = t_rot;
         else
            rot += d_rot;
      }
   }
   
   static float cRot = 0.0;
   glTranslatef((backingWidth*0.5) - (frameSize.width*0.5), (backingHeight*0.5) - (frameSize.height*0.5), 0);
   
   
   glTranslatef((frameSize.width*0.5), (frameSize.height*0.5), 0);
   
   glRotatef(rot, 0.0f, 0.0f, 1.0); cRot += 0.1;
   
   
   float width_ratio = backingWidth / frameSize.width;
   float height_ratio = backingHeight / frameSize.height;
   
   switch (targetOrient)
   {
      case UIInterfaceOrientationPortrait:
         //real_scalex -= 0.1; if (real_scalex < 0.0f) real_scalex = 1.0f;
         //real_scaley -= 0.1; if (real_scaley < 0.0f) real_scaley = 1.0f;
         glScalef(width_ratio * (sx / backingWidth), height_ratio  * (sy / backingHeight), 1.0f);
         break;
      case UIInterfaceOrientationPortraitUpsideDown:
         glScalef(width_ratio * (sx / backingWidth), height_ratio  * (sy / backingHeight), 1.0f);
         break;
      case UIInterfaceOrientationLandscapeLeft:
         glScalef(width_ratio * (sx / backingWidth), height_ratio  * (sy / backingHeight), 1.0f);
         break;
      case UIInterfaceOrientationLandscapeRight:
         glScalef(width_ratio * (sx / backingWidth), height_ratio  * (sy / backingHeight), 1.0f);
         break;
   }
   
   
   // Translate to the middle
   
   glTranslatef(-(frameSize.width*0.5), -(frameSize.height*0.5), 0);
   
   if (isSlaveView) { 
      drawn = [video drawFrame:nil andDisposal:NO];
   } else {
      drawn = [video drawNextFrame:1.0/60 toView:self fromWorker:worker withBackingSize:CGSizeMake(backingWidth, backingHeight)];
   }
   
   glMatrixMode(GL_MODELVIEW);
   glPopMatrix();
   
   
   if (!drawn)
      return;
   
    // Skip drawing when no frame
    /*if (!drawn || !((sx != t_sx) || (sy != t_sy))) {
        if (!gotVideoFrame)
            return;
    }*/
    
    //L0Log(@"vid gotFrame");
   
    //glScalef(480.0/2.0f, 3.0f, 0.0f, 0.0f); // 2, 3
    //glTranslatef(backingWidth/2, backingHeight/2);
    
    
   
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
   
    // TODO
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (BOOL)createFramebuffer {
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        L0Log(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
   
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, backingWidth, 0, backingHeight, -1, 1);
    glGetFloatv(GL_PROJECTION_MATRIX, projectionMatrix);
    
    return YES;
}

- (void)destroyFramebuffer {
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
    
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
}

- (void)layoutSubviews {
    [EAGLContext setCurrentContext:context];
    
    if (!madeFB)
    {
        [self createFramebuffer];
        madeFB = true;
        [self clearView];
    }
}


- (void)drawRect:(CGRect)rect {
    // Drawing code
}


- (void)dealloc {
    if (video)
        self.video = nil;
    
    [self destroyFramebuffer];
    
    [EAGLContext setCurrentContext:nil];
    [context release];  
    [super dealloc];
}

- (bool)zoomAspect
{
    return zoomAspect;
}

- (Video*)video {
    return video;
}

- (void)setVideo:(Video*)theVideo {
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
    
    if (video) {
        [video stop];
        [video release];
    }
    video = [theVideo retain];
    [video setupRenderTexture];
    video.viewRenderInfo = TargetRenderInfoMake(viewFramebuffer, GIFRectMake(0, 0, backingWidth, backingHeight), projectionMatrix);
    
    if (!theVideo)
        return;
    
    float scale[2];
    [video frameClipScale:scale];
    
    // set width and height scale
    sx = 2.0;
    sy = 3.5555555555555554;//3.0;
    t_rot = rot;
    rot = 0.0;
    t_sx = sx;
    t_sy = sy;
    tex_sx = scale[0];
    tex_sy = scale[1];
    
    [self setAspectScale:YES];
    
    // Allocate backing texture
    //CGSize videoSize = video.backingSize;
    //GLint fmt = video.fmt;
    gotVideoFrame = NO;
}

- (void)setZoomAspect:(bool)aValue
{
    zoomAspect = aValue;
    [self setAspectScale:NO];
}

- (void)setAspectScale:(bool)force
{
    [self clearAspectScale];
    CGSize fSize = [video frameSize];
    
    float frame_size[2];
    {
        frame_size[0] = fSize.width;
        frame_size[1] = fSize.height;
    }
    
    float src_ratio = frame_size[1] / frame_size[0]; // height / width == widths to height
    //float base_scale = 1.0;
    float dest_ratio = t_sy / t_sx; // height / width == widths to height
    
    if (src_ratio > dest_ratio) {
        // src is longer than dest, so shrink x and y accordingly
        
        float dest_height = t_sx * src_ratio;
        if (dest_height > t_sy && !zoomAspect) {
            // shrink t_sx by diff
            t_sx -= (dest_height - t_sy) / src_ratio;
        }
        
        t_sy = t_sx * src_ratio;
    } else {
        // src is shorter than dest, so grow x and y accordingly
        
        float dest_width = t_sy / src_ratio;
        if (dest_width > t_sx && !zoomAspect) {
            // shrink t_sy by diff
            t_sy -= (dest_width - t_sx) * src_ratio;
        }
        
        t_sx = t_sy / src_ratio;
    }
    
    if (force) {
        sx = t_sx;
        sy = t_sy;
        rot = t_rot;
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
    } else {
        d_rot = (t_rot - rot) / 25.0;
        d_sx = (t_sx - sx) / 25.0;
        d_sy = (t_sy - sy) / 25.0;
    }
}

- (void)clearAspectScale
{
    switch (targetOrient)
    {
        case UIInterfaceOrientationPortrait:
            t_rot = 0.0;
            t_sx = backingWidth;
            t_sy = backingHeight;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            t_rot = -180.0;
            t_sx = backingWidth;
            t_sy = backingHeight;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            t_rot = -90.0;
            t_sx = backingHeight;
            t_sy = backingWidth;
            break;
        case UIInterfaceOrientationLandscapeRight:
          t_rot = 90.0;
          t_sx = backingHeight;
          t_sy = backingWidth;
            break;
    }
    
    d_rot = (t_rot - rot) / 25.0;
    d_sx = (t_sx - sx) / 25.0;
    d_sy = (t_sy - sy) / 25.0;
}


@end
