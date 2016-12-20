//
//  Video.m
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

#import "Video.h"
#import "VideoTexture.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/EAGL.h>

#import "GifVideo.h"
#import "PngVideo.h"

GLfloat sVidSquareVertices[8];
GLfloat sVidSquareTexcoords[8];

void setPointDrawRect(GLfloat *texCoords, GIFRect src_rect);
void setTexDrawRect(GLfloat *texCoords, int tex_width, int tex_height, GIFRect src_rect);


void TargetRenderInfoSet(TargetRenderInfo info)
{
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, info.frameBuffer);
   glViewport(info.viewport.x, info.viewport.y, info.viewport.width, info.viewport.height);
   
   glMatrixMode(GL_PROJECTION);
   glLoadMatrixf(info.projection);
}

@implementation Video

@synthesize playing;
@synthesize src;
@synthesize thumbDelegate;
@synthesize thumbTime;
@synthesize thumbObject;
@synthesize fps_time;
@synthesize upload_size;
@synthesize fmt;
@synthesize viewRenderInfo;
@dynamic videoType;

- (int)videoType
{
   return VIDEO_NONE;
}

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
    if (self = [super init]) {
        src = source;
        src->retain++;
        context = ctx;
        
        thumbDelegate = nil;
        thumbTime = 0;
        thumbObject = nil;
        fmt = GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG;
        
        if (src) {
            width = 256;
            height = 256;
            bpp = 2;
            
            upload_size = VideoTexture_sizeOfTexture(fmt, width, height, 0);
            fps_time = 1.0/25.0;
            
            v_frame = 0;
            
            req_pos = 0;
        } else {
        }
    }
    
    return self;
}

- (void)dealloc {
    // Context needs to be set to clear resources!
    if ([EAGLContext currentContext] != context)
        [EAGLContext setCurrentContext:context];
    
    [self stop];
    
    if (src)
        VideoSource_release(src);
    
    if (thumbDelegate)
        [thumbDelegate release];
    if (thumbObject)
        [thumbObject release];
   
    if (painter)
       VideoTexture_release(painter);
    painter = NULL;
    
    [self clearRenderTexture];
   
    [super dealloc];
}

- (void)drawPreviousFrame:(GIFRect)frameRect
{
   glActiveTexture(GL_TEXTURE0);
   glEnable(GL_TEXTURE_2D);
   glBindTexture(GL_TEXTURE_2D, texture);
   
   setPointDrawRect(sVidSquareVertices, frameRect);
   setTexDrawRect(sVidSquareTexcoords, width, height, frameRect);
   
   glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (bool)drawNextFrame:(float)dt toView:(PlayerView*)view fromWorker:(VideoWorker*)worker withBackingSize:(CGSize)size
{
   GLfloat squareVertices[8];
   GLfloat squareTexcoords[8];
   
   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   
   glEnableClientState(GL_VERTEX_ARRAY);
   glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   glVertexPointer(2, GL_FLOAT, 0, squareVertices);
   glTexCoordPointer(2, GL_FLOAT, 0, squareTexcoords);
   
   // Grab a new frame
   VideoWorkerFrame_t *frame;
   frame = [worker getFrame:dt];
   //if (!frame) {
   //   return false;
   //}
   
   bool ret = frame && [self drawFrame:frame andDisposal:YES];
   
   if (!ret) {
      if (frame) frame->ready = false;
      return [self drawFrame:nil andDisposal:NO];
      
   } else if (frame) {
      if (frame) frame->ready = false;
      
      // Handle thumbnail
      if (thumbDelegate) {
         if (playing && [NSDate timeIntervalSinceReferenceDate] < thumbTime)
             return true;
         UIImage *img = [self dumpFrame:nil];
         if (img) {
            [thumbDelegate performSelector:@selector(videoDumpedFrame:withObject:) withObject:img withObject:thumbObject];
         }
         [thumbDelegate release];
         if (thumbObject)
            [thumbObject release];
         thumbDelegate = nil;
         thumbObject = nil;
      }
   }
   
   return true;  
}

- (bool)nextFrame:(unsigned char*)data withDt:(float*)dt
{
    if (!VideoSource_eof(src)) {
        // next frame start
        v_frame++;
    } else {
        if (!loop) {
            [self stop];
            return false;
        } else {
            VideoSource_seek(src, 0);
            v_frame = 0;
        }
    }
        
    if (VideoSource_bytesready(src)) {
        VideoSource_startBytes(src);
        if (VideoSource_read(src, data, upload_size) == upload_size) {
            VideoSource_endBytes(src);
            return true;
        } else if (!VideoSource_waitforbytes(src)) {
            // No more bytes
            return false;
        }
    }
    
    return false;
}

- (void)stop
{
    v_frame = 0;
    playing = false;
}

- (void)resetState
{
    VideoSource_seek(src, 0);
}

- (void)play:(bool)doesLoop
{
    loop = doesLoop;
    playing = true;
}


- (void)frameClipScale:(float*)scale
{
    scale[0] = 1.0;
    scale[1] = 1.0;
}

- (CGSize)frameSize
{
    return CGSizeMake(width, height);
}

- (CGSize)backingSize
{
    return CGSizeMake(width, height);
}



- (UIImage*)dumpFrame:(VideoWorkerFrame_t*)frame
{
   UIImage *ret = NULL;
   
   GLuint thumbTexture=0;
   GLuint thumbFramebuffer=0;
   
   int thumbWidth = 64;
   int thumbHeight = 64;
   
   glGenTextures(1, &thumbTexture);
   glBindTexture(GL_TEXTURE_2D, thumbTexture);
   
   // Create framebuffer object
   glGenFramebuffersOES(1, &thumbFramebuffer);
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, thumbFramebuffer);
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   
   //char *temp = (char*)malloc(width*height*4);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, thumbWidth, thumbHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
   //free(temp);
   
   glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, thumbTexture, 0);
   
   if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES)
   {
      glGetError();
      
      //glBindFramebufferOES(GL_FRAMEBUFFER_OES, thumbFramebuffer);
      glViewport(0, 0, thumbWidth, thumbHeight);
      glClearColor(0,0,0,0);
      glClear(GL_COLOR_BUFFER_BIT);
      
      // Now drawing to texture
      glMatrixMode(GL_PROJECTION);
      glLoadIdentity();
      glOrthof(0, thumbWidth, 0, thumbHeight, -1, 1);
      glMatrixMode(GL_MODELVIEW);
      glPushMatrix();
      glLoadIdentity();
      
      glClearColor(0, 0, 0, 0);
      glClear(GL_COLOR_BUFFER_BIT);
      
      CGSize frameSize = [self frameSize];
      
      float frame_size[2];
      {
         frame_size[0] = frameSize.width;
         frame_size[1] = frameSize.height;
      }
      
      float sx = thumbWidth;
      float sy = thumbHeight;
      
      float src_ratio = frame_size[1] / frame_size[0]; // height / width == widths to height
      //float base_scale = 1.0;
      float dest_ratio = thumbHeight / thumbWidth; // height / width == widths to height
      
      if (src_ratio > dest_ratio) {
         // src is longer than dest, so shrink x and y accordingly
         
         float dest_height = sx * src_ratio;
         if (dest_height > sy) {
            // shrink t_sx by diff
            sx -= (dest_height - sy) / src_ratio;
         }
         
         sy = sx * src_ratio;
      } else {
         // src is shorter than dest, so grow x and y accordingly
         
         float dest_width = sy / src_ratio;
         if (dest_width > sx) {
            // shrink t_sy by diff
            sy -= (dest_width - sx) * src_ratio;
         }
         
         sx = sy / src_ratio;
      }
      
      // See if we have a frame ready
      
      
      glTranslatef((thumbWidth*0.5) - (frameSize.width*0.5), (thumbHeight*0.5) - (frameSize.height*0.5), 0);
      
      glTranslatef((frameSize.width*0.5), (frameSize.height*0.5), 0);
      
      float width_ratio = thumbWidth / frameSize.width;
      float height_ratio = thumbHeight / frameSize.height;
      
      glScalef(width_ratio * (sx / thumbWidth), height_ratio  * (sy / thumbHeight), 1.0f);
      
      glTranslatef(-(frameSize.width*0.5), -(frameSize.height*0.5), 0);

            
      // Draw frame
      
      if ([self drawFrame:frame andDisposal:NO]) {
         // Now we can make the bitmap
         CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
         unsigned char *mem = (unsigned char*)malloc(thumbWidth * thumbHeight * 4);
         CGContextRef ctx = CGBitmapContextCreate(mem,
                                                  thumbWidth,
                                                  thumbHeight,
                                                  8,
                                                  thumbWidth * 4,
                                                  colorspace,
                                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
         CGColorSpaceRelease(colorspace);
         
         if (ctx) {          
            // Copy pixels...
            memset(mem, '\0', thumbWidth*thumbHeight*4);
            glReadPixels(0, 0, thumbWidth, thumbHeight, GL_RGBA, GL_UNSIGNED_BYTE, mem);
            /*
             for (int y=0; y<thumbHeight; y++) {
             ptr = fData + (thumbWidth * y);
             memcpy(dat, ptr, thumbWidth*4);
             dat += thumbWidth*4;
             }*/
            
            CGImageRef img = CGBitmapContextCreateImage(ctx);
            ret = [UIImage imageWithCGImage:img];
            
            CGContextRelease(ctx);
            CGImageRelease(img);
         }
         
         free(mem);
      }
      
      glMatrixMode(GL_MODELVIEW);
      glPopMatrix();
   }
   
   // Cleanup
   glDeleteFramebuffersOES(1, &thumbFramebuffer);
   glDeleteTextures(1, &thumbTexture);
   return ret;
}


- (bool)setupRenderTexture
{
   if (framebuffer != 0) {
      [self clearRenderTexture];
   }
   
   glGenTextures(1, &texture);
   glBindTexture(GL_TEXTURE_2D, texture);
   
   // Create framebuffer object
   glGenFramebuffersOES(1, &framebuffer);
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   
   //char *temp = (char*)malloc(width*height*4);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
   //free(temp);
   
   glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, texture, 0);
   
   if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
   {
      // error
      [self clearRenderTexture];
      return false;
   }
   
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   
   glGetError();
   
   //glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
   glViewport(0, 0, width, height);
   glClearColor(0,0,0,0);
   glClear(GL_COLOR_BUFFER_BIT);
   
   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrthof(0, width, 0, height, -1, 1);
   disposalRenderInfo.frameBuffer = framebuffer;
   disposalRenderInfo.viewport = GIFRectMake(0, 0, width, height);
   glGetFloatv(GL_PROJECTION_MATRIX, disposalRenderInfo.projection);
   
   return true;
}

- (void)clearRenderTexture
{
   if (framebuffer == 0)
      return;
   glDeleteFramebuffersOES(1, &framebuffer);
   glDeleteTextures(1, &texture);
   
   glGetError();
   
   framebuffer = 0;
   texture = 0;
}

- (void)setPaintHead:(VideoTexture*)aPainter
{
   glActiveTexture(GL_TEXTURE0);
   glEnable(GL_TEXTURE_2D);
   glBindTexture(GL_TEXTURE_2D, aPainter->tex);
   glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE); 
}

+ (Video*)videoByType:(int)type withSource:(VideoSource*)source inContext:(EAGLContext*)context
{
   switch (type) {
      case VIDEO_GIF:
         return [[[GifVideo alloc] initWithSource:source inContext:context] autorelease];
         break;
      case VIDEO_PNG:
         return [[[PngVideo alloc] initWithSource:source inContext:context] autorelease];
         break;
      default:
         return NULL;
         break;
   }
}


@end
