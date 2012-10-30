//
//  SPImage.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/20/11.
/*
Copyright (c) 2011, Spotify AB
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Spotify AB nor the names of its contributors may 
      be used to endorse or promote products derived from this software 
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SPOTIFY AB BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "SPImage.h"
#import "SPSession.h"
#import "SPURLExtensions.h"

@interface SPImageCallbackProxy : NSObject
// SPImageCallbackProxy is here to bridge the gap between -dealloc and the 
// playlist callbacks being unregistered, since that's done async.
@property (nonatomic, readwrite, assign) __unsafe_unretained SPImage *image;
@end

@implementation SPImageCallbackProxy
@synthesize image;
@end

@interface SPImage ()

-(void) cacheSpotifyURL;

@property (nonatomic, readwrite) const byte *imageId;
@property (nonatomic, readwrite, strong) SPPlatformNativeImage *image;
@property (nonatomic, readwrite) sp_image *spImage;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite) __unsafe_unretained SPSession *session;
@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, strong) SPImageCallbackProxy *callbackProxy;

@end

static void image_loaded(sp_image *image, void *userdata) {
	
	SPImageCallbackProxy *proxy = (__bridge SPImageCallbackProxy *)userdata;
	if (!proxy.image) return;
	
	BOOL isLoaded = sp_image_is_loaded(image);
	SPPlatformNativeImage *im = nil;
	
	if (isLoaded) {
		size_t size;
		const byte *data = sp_image_data(proxy.image.spImage, &size);
		
		if (size > 0)
			im = [[SPPlatformNativeImage alloc] initWithData:[NSData dataWithBytes:data length:size]];
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		proxy.image.image = im;
		proxy.image.loaded = isLoaded;
	});
}

@implementation SPImage {
	BOOL hasRequestedImage;
	BOOL hasStartedLoading;
	SPPlatformNativeImage *_image;
}

static NSMutableDictionary *imageCache;

+(SPImage *)imageWithImageId:(const byte *)imageId inSession:(SPSession *)aSession {

	SPAssertOnLibSpotifyThread();
	
    if (imageCache == nil) {
        imageCache = [[NSMutableDictionary alloc] init];
    }
    
	if (imageId == NULL) {
		return nil;
	}
	
	NSData *imageIdAsData = [NSData dataWithBytes:imageId length:SPImageIdLength];
	SPImage *cachedImage = [imageCache objectForKey:imageIdAsData];
	
	if (cachedImage != nil)
		return cachedImage;
	
	cachedImage = [[SPImage alloc] initWithImageStruct:NULL
											   imageId:imageId
											 inSession:aSession];
	[imageCache setObject:cachedImage forKey:imageIdAsData];
	return cachedImage;
}

+(void)imageWithImageURL:(NSURL *)imageURL inSession:(SPSession *)aSession callback:(void (^)(SPImage *image))block {
	
	if ([imageURL spotifyLinkType] != SP_LINKTYPE_IMAGE) {
		if (block) block(nil);
		return;
	}
	
	dispatch_libspotify_async(^{
		
		SPImage *spImage = nil;
		sp_link *link = [imageURL createSpotifyLink];
		sp_image *image = sp_image_create_from_link(aSession.session, link);
		
		if (link != NULL)
			sp_link_release(link);
		
		if (image != NULL) {
			spImage = [self imageWithImageId:sp_image_image_id(image) inSession:aSession];
			sp_image_release(image);
		}
		
		if (block) dispatch_async(dispatch_get_main_queue(), ^() { block(spImage); });
	});
}

#pragma mark -

-(id)initWithImageStruct:(sp_image *)anImage imageId:(const byte *)anId inSession:aSession {
	
	SPAssertOnLibSpotifyThread();
	
    if ((self = [super init])) {
		
		self.session = aSession;
		self.imageId = anId;
		
		if (anImage != NULL) {
			self.spImage = anImage;
			sp_image_add_ref(self.spImage);
			
			self.callbackProxy = [[SPImageCallbackProxy alloc] init];
			self.callbackProxy.image = self;
			
			sp_image_add_load_callback(self.spImage,
									   &image_loaded,
									   (__bridge void *)(self.callbackProxy));
			
			BOOL isLoaded = sp_image_is_loaded(self.spImage);
			SPPlatformNativeImage *im = nil;
			
			if (isLoaded) {
				size_t size;
				const byte *data = sp_image_data(self.spImage, &size);
				
				if (size > 0)
					im = [[SPPlatformNativeImage alloc] initWithData:[NSData dataWithBytes:data length:size]];
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				[self cacheSpotifyURL];
				self.image = im;
				self.loaded = isLoaded;
			});
        }
    }
    return self;
}

-(sp_image *)spImage {
#if DEBUG
	SPAssertOnLibSpotifyThread();
#endif 
	return _spImage;
}

@synthesize spImage = _spImage;
@synthesize loaded;
@synthesize session;
@synthesize spotifyURL;
@synthesize imageId;
@synthesize callbackProxy;

-(SPPlatformNativeImage *)image {
	if (_image == nil && !hasRequestedImage)
		[self startLoading];
	return _image;
}

-(void)setImage:(SPPlatformNativeImage *)anImage {
	if (_image != anImage) {
		_image = anImage;
	}
}

#pragma mark -

-(void)startLoading {

	if (hasStartedLoading) return;
	hasStartedLoading = YES;
	
	dispatch_libspotify_async(^{
		
		if (self.spImage != NULL)
			return;
		
		sp_image *newImage = sp_image_create(self.session.session, self.imageId);
		self.spImage = newImage;
		
		if (self.spImage != NULL) {
			[self cacheSpotifyURL];
			
			// Clear out previous proxy.
			self.callbackProxy.image = nil;
			self.callbackProxy = nil;
			
			self.callbackProxy = [[SPImageCallbackProxy alloc] init];
			self.callbackProxy.image = self;
			
			sp_image_add_load_callback(self.spImage, &image_loaded, (__bridge void *)(self.callbackProxy));
			BOOL isLoaded = sp_image_is_loaded(self.spImage);
			SPPlatformNativeImage *im = nil;
			
			if (isLoaded) {
				size_t size;
				const byte *data = sp_image_data(self.spImage, &size);
				
				if (size > 0)
					im = [[SPPlatformNativeImage alloc] initWithData:[NSData dataWithBytes:data length:size]];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				hasRequestedImage = YES;
				self.image = im;
				self.loaded = isLoaded;
			});
		}
	});
	
}

-(void)dealloc {

	sp_image *outgoing_image = _spImage;
	SPImageCallbackProxy *outgoingProxy = self.callbackProxy;
	self.callbackProxy.image = nil;
	self.callbackProxy = nil;
    
    dispatch_libspotify_async(^() {
		if (outgoing_image) sp_image_remove_load_callback(outgoing_image, &image_loaded, (__bridge void *)outgoingProxy);
		if (outgoing_image) sp_image_release(outgoing_image);
	});
}

-(void)cacheSpotifyURL {
	
	dispatch_libspotify_async(^{

		if (self.spotifyURL != NULL)
			return;
		
		sp_link *link = sp_link_create_from_image(self.spImage);
		
		if (link != NULL) {
			NSURL *url = [NSURL urlWithSpotifyLink:link];
			sp_link_release(link);
			dispatch_async(dispatch_get_main_queue(), ^{
				self.spotifyURL = url;
			});
		}
	});
}

@end
