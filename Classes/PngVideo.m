//
//  PngVideo.m
//  webplay
//
//  Created by Stuart Urquhart on 16/04/2012.
//
// (C) James S Urquhart 2012 - 2016
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

#import "webplayAppDelegate.h"
#import "PngVideo.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "PlayerView.h"
#import "VideoSource.h"

#include "png.h"
#include "pngpriv.h"

#define PNG_READ_TILL_OK 1
#define PNG_READ_TILL_NOBYTES 0
#define PNG_READ_TILL_NOBYTES_NOCHUNKSTART -1
#define PNG_READ_TILL_EOF -2
/*
int png_reset_actl(png_structp png_ptr, png_infop info_ptr, int numframes, int mode)
{
   png_ptr->num_frames_read = numframes;
}

int png_remember_state(png_structp png_ptr, png_infop info_ptr, int *num_frames, int *mode)
{
   png_read_reset(png_ptr);
   *num_frames = png_ptr->num_frames_read;
   *mode = png_ptr->mode;
}*/

int png_read_till_next_image_chunk(png_structp png_ptr, png_infop info_ptr)
{
   png_byte have_chunk_after_DAT; /* after IDAT or after fdAT */
   VideoSource *src = png_get_io_ptr(png_ptr);
   int startPos = src->pos;
   //png_crc_finish(png_ptr, 0); /* CRC from last IDAT or fdAT chunk */
   //png_read_reset(png_ptr);
   
   
   int ret = PNG_READ_TILL_NOBYTES;
   int bytes = 0;
   int length;
   int readbytes = 0;
   for (;;)
   {
      png_byte chunk_length[4];
      png_byte chunk_tag[4];
      png_uint_32 length;
      
      // Read length + tag
      VideoSource *src = png_get_io_ptr(png_ptr);
      bytes = VideoSource_read(src, chunk_length, 4);
      if (bytes != 4)
         break;
      bytes = VideoSource_read(src, chunk_tag, 4);
      if (bytes != 4)
         break;
      
      length = png_get_uint_31(png_ptr, chunk_length);
      png_ptr->chunk_name = PNG_CHUNK_FROM_STRING(chunk_tag);
      
      // See if we are long enough
      readbytes = VideoSource_seekread(src, length);
      if (readbytes != length)
         break;
      
      bytes = VideoSource_seekread(src, 4); // skip crc
      if (bytes != 4)
         break;
      
      if (png_ptr->chunk_name == png_IDAT)
      {
         ret = PNG_READ_TILL_OK;
         break;
      }
      else if (png_ptr->chunk_name == png_fdAT)
      {
         ret = PNG_READ_TILL_OK;
         break;
      }
      else if (png_ptr->chunk_name == png_IEND)
      {
         ret = PNG_READ_TILL_EOF;
         break;
      }
   }
   
   VideoSource_seek(src, startPos);
   return ret;
}

// Version of frame header read which doesn't calculate crc and places stream at next chunk
void 
png_read_frame_head_nocrc(png_structp png_ptr, png_infop info_ptr)
{
   png_byte have_chunk_after_DAT; /* after IDAT or after fdAT */
   
   png_debug(0, "Reading frame head");
   
   if (!(png_ptr->mode & PNG_HAVE_acTL))
      png_error(png_ptr, "attempt to png_read_frame_head() but "
                "no acTL present");
   
   /* do nothing for the main IDAT */
   if (png_ptr->num_frames_read == 0)
      return;
   
   png_ptr->mode &= ~PNG_HAVE_fcTL;
   
   have_chunk_after_DAT = 0;
   for (;;)
   {
      png_byte chunk_length[4];
      png_byte chunk_tag[4];
      png_uint_32 length;
      
      png_read_data(png_ptr, chunk_length, 4);
      length = png_get_uint_31(png_ptr, chunk_length);
      
      png_reset_crc(png_ptr);
      png_crc_read(png_ptr, chunk_tag, 4);
      png_ptr->chunk_name = PNG_CHUNK_FROM_STRING(chunk_tag);
      
      if (png_ptr->chunk_name == png_IDAT)
      {
         /* discard trailing IDATs for the first frame */
         if (have_chunk_after_DAT || png_ptr->num_frames_read > 1)
            png_error(png_ptr, "png_read_frame_head(): out of place IDAT");
         png_crc_finish(png_ptr, length);
      }
      else if (png_ptr->chunk_name == png_fcTL)
      {
         png_handle_fcTL(png_ptr, info_ptr, length);
         have_chunk_after_DAT = 1;
      }
      else if (png_ptr->chunk_name == png_fdAT)
      {
         png_ensure_sequence_number(png_ptr, length);
         
         /* discard trailing fdATs for frames other than the first */
         if (!have_chunk_after_DAT && png_ptr->num_frames_read > 1)
            png_crc_finish(png_ptr, length - 4);
         else if(png_ptr->mode & PNG_HAVE_fcTL)
         {
            png_ptr->idat_size = length - 4;
            png_ptr->mode |= PNG_HAVE_IDAT;
            
            break;
         }
         else
            png_error(png_ptr, "png_read_frame_head(): out of place fdAT");
      }
      else
      {
         png_warning(png_ptr, "Skipped (ignored) a chunk "
                     "between APNG chunks");
         png_crc_finish(png_ptr, length);
      }
   }
   
}

extern GLint sMaxTextureSize;

@implementation PngVideo


int goodSize(int val);


- (int)videoType
{
   return VIDEO_PNG;
}

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
   if (self = [super initWithSource:source inContext:ctx]) {
      // hmm....
      disposal = 0;
      trans = false;
      thumbDelegate = nil;
      thumbTime = 0;
      
      bpp = 8;
      bestQuality = true;
      
      framebuffer = 0;
      texture = 0;
      
      painter = NULL;
      
      [self resetState:YES];
      
      if (upload_size == 0 || pnginfo == 0x0)
      {
         [self release];
         return nil;
      }
   }
   
   return self;
}

- (void)dealloc {
   // free gif...
   
   if (pngfile) {
      //png_read_end(pnginfo, NULL);
      png_destroy_read_struct(&pngfile, &pnginfo, NULL);
   }
   
   [super dealloc];
}

void setPointDrawRect(GLfloat *texCoords, GIFRect src_rect);

void setTexDrawRect(GLfloat *texCoords, int tex_width, int tex_height, GIFRect src_rect);

// Copies raw bytes
void copyImageBits8(unsigned char *dest, unsigned char *src, int width, int height, int stride);

// Copies 256 color palette + data
void copyImageBitsPal8(unsigned char *dest, unsigned char *src, int width, int height, int stride);


void copyImageBits32(unsigned char *dest, unsigned char *src, int width, int height, int stride)
{
   unsigned int *ptr = dest;
   unsigned int *srcptr = src;
   for (int i=0; i<height; i++) {
      ptr = (unsigned int*)(dest) + (stride*i);
      for (int x=0; x<width; x++) {
         *ptr++ = *srcptr++;
      }
   }
}

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal
{
   // Don't draw if we haven't recieved frames yet
   if (frame == NULL && last_frame.data == NULL)
      return false;
   
   glEnable(GL_BLEND);
   
   glEnableClientState(GL_VERTEX_ARRAY);
   glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   glVertexPointer(2, GL_FLOAT, 0, sVidSquareVertices);
   glTexCoordPointer(2, GL_FLOAT, 0, sVidSquareTexcoords);
   
   // draw new previous frame
   if (updateDisposal) {
      // Clear pixels if we're at the first frame
      
      // Now drawing to texture
      TargetRenderInfoSet(disposalRenderInfo);
      
      glMatrixMode(GL_MODELVIEW);
      glPushMatrix();
      glLoadIdentity();
      
      /*glPushMatrix();
      glTranslatef(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width);
      glPopMatrix();*/
      
      
      if (frame && frame->reset) {
         glClearColor(1,0,0,0);
         glClear(GL_COLOR_BUFFER_BIT);
      } else {
            
         GIFRect tex_rect = last_frame.rect;
         tex_rect.x = tex_rect.y = 0;
         setPointDrawRect(sVidSquareVertices, last_frame.rect);
         setTexDrawRect(sVidSquareTexcoords, painter->width, painter->height, tex_rect);
         
         switch (last_frame.blend_type) {
            case BLEND_OVER:
               // alpha * foreground + (1-alpha) * background
               glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
               break;
            case BLEND_SOURCE:
               // {foreground}*sourceAlpha + {background}*{0,0,0,0}
               glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
               break;
         }
         
         switch (last_frame.disposal_type) {
            case DISPOSE_RESET:
               // Clear all pixels
               glEnable(GL_SCISSOR_TEST);
               glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
               glClearColor(0,0,0,0);
               glClear(GL_COLOR_BUFFER_BIT);
               glDisable(GL_SCISSOR_TEST);
               break;
            case DISPOSE_CLEARBG:
               // Clear BG color
               glEnable(GL_SCISSOR_TEST);
               glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
               glClearColor(last_frame.clear_r / 255.0f, last_frame.clear_g  / 255.0f, last_frame.clear_b  / 255.0f, last_frame.clear_a  / 255.0f);
               glClear(GL_COLOR_BUFFER_BIT);
               glDisable(GL_SCISSOR_TEST);
               break;
            case DISPOSE_PREVIOUSBG:
               // Do nothing
               break;
            case DISPOSE_NONE:
            default:
               // Copy current frame to previous
               //setPointDrawRect(sVidSquareVertices, last_frame.rect);
               //setTexDrawRect(sVidSquareTexcoords, painter->width, painter->height, tex_rect);
               
               glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
               /*glEnable(GL_SCISSOR_TEST);
                glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
                glClearColor(0,1,0,1);
                glClear(GL_COLOR_BUFFER_BIT);
                glDisable(GL_SCISSOR_TEST);*/
               break;
         }
      }
      
      // Reset state
      glMatrixMode(GL_MODELVIEW);
      glPopMatrix();
      
      // Set player view render mode
      TargetRenderInfoSet(viewRenderInfo);
   }
   
   //glDisable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
   
   // Update paint head
   if (frame)
   {
      if (!VideoTexture_lock(painter)) {
         return false;
      }
      memset(painter->data, '\0', upload_size);
      copyImageBits32(painter->data, frame->data, frame->rect.width, frame->rect.height, painter->width);
      VideoTexture_unlock(painter);
   }
   
   // First, render last frame (ALL of it)
   if ((frame && !frame->reset) || !(!frame && last_frame.reset)) {
      GIFRect rect;
      rect.x = 0;
      rect.y = 0;
      rect.width = png_width;
      rect.height = png_height;
      [self drawPreviousFrame:rect];
   }
   
   //debugPrintRenderBuffer();
   
   if (frame) last_frame = *frame;
   GIFRect tex_rect = last_frame.rect;
   tex_rect.x = tex_rect.y = 0;
   
   // Set new frame blend type
   switch (last_frame.blend_type) {
         
      case BLEND_OVER:
         // alpha * foreground + (1-alpha) * background
         glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
         break;
      case BLEND_SOURCE:
         glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
         break;
   }
   
   // draw new frame
   [self setPaintHead:painter];
   setPointDrawRect(sVidSquareVertices, last_frame.rect);
   setTexDrawRect(sVidSquareTexcoords, painter->width, painter->height, tex_rect);
   glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
   
   // if (sFrameCount++ >= 2) {
   //    return true;
   // }
   //return false;
   
   return true;   
}


extern VideoWorkerFrame_t *errFrame;

extern int sFrameCount;

void debugPrintRenderBuffer();


char pngToGifDisposal(unsigned char dop)
{
   // Disposal
   switch (dop) {
      case PNG_DISPOSE_OP_BACKGROUND:
         return DISPOSE_RESET;
         break;
      case PNG_DISPOSE_OP_PREVIOUS:
         return DISPOSE_PREVIOUSBG;
         break;
      default:
         return DISPOSE_NONE;
         break;
   }
}

char pngToGifBlend(unsigned char bop)
{
   // Blending
   switch (bop) {
      case PNG_BLEND_OP_OVER:
         return BLEND_OVER;
         break;
      case PNG_BLEND_OP_SOURCE:
      default:
         return BLEND_SOURCE;
         break;
   }
}

- (bool)nextFrame:(VideoWorkerFrame_t*)frame
{
   int j;
   unsigned char *data = frame->data;
   inError = false;
   
   unsigned short  delay_num = 1;
   unsigned short  delay_den = 10;
   unsigned char   dop = 0;
   unsigned char   bop = 0;
   
   // Error?!
   if (pnginfo && setjmp(png_jmpbuf(pngfile))) {
      inError = true;
      [self stop];
      return false;
   }
   
   //L0Log(@"frame == %d, sync == %f, fps == %f", frame, sync_time, fps_time);
   
   // flushState leaves us with the main png header chunks loaded and the image chunk
   // loaded with png_read_till_next_image_chunk, so to start off with we need to 
   // simply wait to read the image
   
   if (!readFirstImage) {
      // Currently reading headers?
      if (!VideoSource_bytesready(src))
         return false;
      
      // done waiting
      VideoSource_endBytes(src);
      
      // Read the info
      png_read_update_info(pngfile, pnginfo);
      
      frame->dt = -1;
      frame->rect.x = 0;
      frame->rect.y = 0;
      frame->rect.height = png_height;
      frame->rect.width = png_width;
      frame->disposal_type = DISPOSE_NONE;
      frame->blend_type = BLEND_OVER;
      current_frame = 0;
      frame->reset = true;
      
      frame->clear_a = frame->clear_r = frame->clear_b = frame->clear_g = 0;
      
      if (!inError) {
         png_bytepp rows_frame = (png_bytepp)malloc(png_height*sizeof(png_bytep));
         //int next = width - png_width;
         
         for (j=0; j<frame->rect.height; j++)
            rows_frame[j] = data + (j*frame->rect.width*4);
         
         png_read_image(pngfile, rows_frame);
         
         free(rows_frame);
         
         png_crc_finish(pngfile, 0); /* CRC from last IDAT or fdAT chunk */
         png_read_reset(pngfile);
      }
      
      readFirstImage = true;

      // Stop if we are static
      if (!anim) {
         //[self stop];
         //return true;
      }
      
      // Skip the first frame
      if (first)
         return false;
      
      if (anim) {
         png_get_next_frame_fcTL(pngfile, pnginfo, &frame->rect.width, &frame->rect.height, &frame->rect.x, &frame->rect.y, &delay_num, &delay_den, &dop, &bop);
         
         delay_den = delay_den == 0 ? 100 : delay_den;
         delay_num = delay_num == 0 ? 1 : delay_num;
         frame->dt = ((float)delay_num / delay_den);
         frame->clear_a = frame->clear_r = frame->clear_b = frame->clear_g = 0;
         
         currentTime += frame->dt;
         
         // Disposal
         frame->disposal_type = pngToGifDisposal(dop);
         // Blending
         frame->blend_type = pngToGifBlend(bop);
         
         frame->reset = true;
         current_frame++;
      }
      
      // Error occured? odd PNG!
      if (inError) {
         [self stop];
         return false;
      }
      
      return !inError;
   }
   
   // First stage: read all of the blocks
   if (!readingFrame)
   {
      // Currently reading headers?
      if (!VideoSource_bytesready(src))
         return false;
      
      VideoSource_startBytes(src); // start pos (if not set)
      
      // Explore chunks till the next image chunk
      int ret = png_read_till_next_image_chunk(pngfile, pnginfo);
      
      // First check if we are at the end of the stream
      if (current_frame >= frames || VideoSource_eof(src) || ret == PNG_READ_TILL_EOF) {
         // Return to start
         VideoSource_endBytes(src);
         
         // loop or stop completely
         if (!loop) {
            [self stop];
            return false;
         } else {
            // Start again!
            [self resetState:NO];
            return false;
         }
      }
      
      // Abort if we need more bytes
      if (ret == PNG_READ_TILL_NOBYTES) {
         return false;
      }
      
      VideoSource_endBytes(src); // finished waiting
      
      // First, read animation header IF PRESENT
      if (anim) {
         png_read_frame_head_nocrc(pngfile, pnginfo);
         
         int ret = png_get_next_frame_fcTL(pngfile, pnginfo, &frame->rect.width, &frame->rect.height, &frame->rect.x, &frame->rect.y, &delay_num, &delay_den, &dop, &bop);
         
         delay_den = delay_den == 0 ? 100 : delay_den;
         delay_num = delay_num == 0 ? 1 : delay_num;
         frame->dt = ((float)delay_num / delay_den);
         frame->clear_a = frame->clear_r = frame->clear_b = frame->clear_g = 0;
         
         currentTime += frame->dt;
         
         // Disposal
         frame->disposal_type = pngToGifDisposal(dop);
         // Blending
         frame->blend_type = pngToGifBlend(bop);
         
         frame->reset = current_frame == 0 && first;
         current_frame++;
      } else {
         frame->dt = -1;
         frame->rect.x = 0;
         frame->rect.y = 0;
         frame->rect.height = png_height;
         frame->rect.width = png_width;
         frame->disposal_type = DISPOSE_NONE;
         frame->blend_type = BLEND_OVER;
         current_frame = 0;
         frame->reset = true;
      }
      
      if (!inError) {
         png_bytepp rows_frame = (png_bytepp)malloc(png_height*sizeof(png_bytep));
         int next = width - png_width;
         
         for (j=0; j<frame->rect.height; j++)
            rows_frame[j] = data + (j*frame->rect.width*4);
         
         png_read_image(pngfile, rows_frame);
         
         free(rows_frame);
         
         png_crc_finish(pngfile, 0); /* CRC from last IDAT or fdAT chunk */
         png_read_reset(pngfile);
         
         return true;
      }
      
      if (inError) {
         if (!VideoSource_waitforbytes(src)) // no more data?
         {
            VideoSource_endBytes(src);
            
            // loop or stop completely
            if (!loop) {
               [self stop];
               return false;
            } else {
               // Start again!
               [self resetState:NO];
               return false;
            }
         }
         else
         {  // NOTE: should not get here
            // Waiting for data, flush the damn state
            [self resetState:NO];
         }
      }
   }
   
   return false;
}

static void pngReadDataFn(png_structp  png_ptr,
                          png_bytep   data,
                          png_size_t  length)
{
   VideoSource *src = png_get_io_ptr(png_ptr);
   VideoSource_read(src, (unsigned char*)data, length);
}

static void pngFlushDataFn(png_structp png_ptr)
{
   //
}

static png_voidp pngMallocFn(png_structp png_ptr, png_size_t size)
{
   return (png_voidp)malloc(size);
}

static void pngFreeFn(png_structp png_ptr, png_voidp mem)
{
   free(mem);
}


//--------------------------------------
static void pngFatalErrorFn(png_structp     png_ptr,
                            png_const_charp pMessage)
{
   VideoSource *src = png_get_io_ptr(png_ptr);
   
   if (src->user_ptr) {
      [(PngVideo*)(src->user_ptr) setError];
   }
}


//--------------------------------------
static void pngWarningFn(png_structp png_ptr, png_const_charp pMessage)
{
}

- (void)setError
{
   inError = YES;
}

- (void)resetState:(bool)gl
{
   VideoSource_seek(src, 0);
   
   [self flushState];
   
   if (!pnginfo)
      return;
   
   width  = goodSize(png_width);
   height = goodSize(png_height);
   
   if (width > sMaxTextureSize || height > sMaxTextureSize)
   {
      upload_size = 0;
      png_destroy_read_struct(&pngfile, &pnginfo, NULL);
      pngfile = NULL;
      pnginfo = NULL;
      return;
   }
   
   // texture format
   fmt = GL_RGBA;
   upload_size = VideoTexture_sizeOfTexture(fmt, width, height, 0);
   
   if (gl) {
      if (painter)
         VideoTexture_release(painter);
      
      painter = VideoTexture_init(width, height, fmt);
   }
}

- (void)flushState
{
   int oldPos = src->pos;
   VideoSource_seek(src, 0);
   VideoSource_endBytes(src); // no tracking
   
   unsigned char header[8];
   VideoSource_read(src, header, 8);
   
   if (pngfile) {
      //png_read_end(pnginfo, NULL);
      png_destroy_read_struct(&pngfile, &pnginfo, NULL);
   }
   
   
   pngfile = png_create_read_struct_2(PNG_LIBPNG_VER_STRING,
                                      NULL,
                                      pngFatalErrorFn,
                                      pngWarningFn,
                                      NULL,
                                      pngMallocFn,
                                      pngFreeFn);
   pnginfo = png_create_info_struct(pngfile);
   
   inError = false;
   readingFrame = false;
   // determine master width, height
   
   // Error!
   if (pnginfo && setjmp(png_jmpbuf(pngfile))) {
      if (pngfile) png_destroy_read_struct(&pngfile, &pnginfo, NULL);
      pngfile = NULL;
      pnginfo = NULL;
      return;
   }
   
   if (pnginfo) {
      src->user_ptr = self;
      png_set_read_fn(pngfile, src, pngReadDataFn);
      
      //png_init_io(pngfile, src);
      png_set_sig_bytes(pngfile, 8);
      png_read_info(pngfile, pnginfo);
      png_set_expand(pngfile);
      png_set_strip_16(pngfile);
      png_set_gray_to_rgb(pngfile);
      png_set_add_alpha(pngfile, 0xff, PNG_FILLER_AFTER);
      //png_set_bgr(pngfile);
      (void)png_set_interlace_handling(pngfile);
      png_width    = png_get_image_width(pngfile, pnginfo);
      png_height   = png_get_image_height(pngfile, pnginfo);
      rowbytes = png_get_rowbytes(pngfile, pnginfo);
      
      VideoSource_startBytes(src);
      
      // Ensure we have enough bytes to wait for the first image to load
      if (png_read_till_next_image_chunk(pngfile, pnginfo) < PNG_READ_TILL_NOBYTES) {
         png_destroy_read_struct(&pngfile, NULL, NULL);
         pngfile = NULL;
         pnginfo = NULL;
         VideoSource_endBytes(src);
         return; 
      }
   } else {
      png_destroy_read_struct(&pngfile, NULL, NULL);
      pngfile = NULL;
      pnginfo = NULL;
      return;
   }
   
   if (inError) {
      if (pngfile) png_destroy_read_struct(&pngfile, &pnginfo, NULL);
      pngfile = NULL;
      pnginfo = NULL;
      return;
   }
   
   
   // todo: reset num_frames_read on flush
   
   last_frame.data = NULL;
   plays = 0;
   frames = 0;
   current_frame = 0;
   first = (png_get_first_frame_is_hidden(pngfile, pnginfo) == 0) ? 0 : 1;
   anim = png_get_acTL(pngfile, pnginfo, &frames, &plays);
   readFirstImage = false;
   
   if (frames == 0)
      frames = 1;
   
   if (false) {
      VideoSource_seek(src, oldPos);
   } else {
      currentTime = 0.0;
   }
}

- (void)frameClipScale:(float*)scale
{
   if (pnginfo) {
      scale[0] = (float)png_width / (float)width;
      scale[1] = (float)png_height / (float)height;
   } else {
      scale[0] = 1.0;
      scale[1] = 1.0;
   }
}

- (CGSize)frameSize
{
   if (pnginfo)
      return CGSizeMake(png_width, png_height);
   else
      return CGSizeMake(width, height);
}

@end
