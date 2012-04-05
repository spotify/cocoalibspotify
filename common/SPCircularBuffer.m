//
//  SPCircularBuffer.m
//  Viva
//
//  Created by Daniel Kennett on 4/9/11.
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

#import "SPCircularBuffer.h"

@implementation SPCircularBuffer

-(id)init {
    return [self initWithMaximumLength:1024];
}

-(id)initWithMaximumLength:(NSUInteger)size {
	self = [super init];
    if (self) {
        // Initialization code here.
		buffer = malloc(size);
		maximumLength = size;
		[self clear];
    }
    
    return self;
}

-(void)clear {
	@synchronized(self) {
		memset(buffer, 0, maximumLength);
		dataStartOffset = 0;
		dataEndOffset = 0;
		empty = YES;
	}
}

-(NSUInteger)attemptAppendData:(const void *)data ofLength:(NSUInteger)dataLength {
    
    NSUInteger availableBufferSpace = self.maximumLength - self.length;
    
	@synchronized(self) {
        
		if (availableBufferSpace == 0)
			return 0;
		
		NSUInteger writableByteCount = MIN(dataLength, availableBufferSpace);
		NSUInteger directCopyByteCount = MIN(writableByteCount, self.maximumLength - (dataEndOffset + 1));
		NSUInteger wraparoundByteCount = writableByteCount - directCopyByteCount;
		
		if (directCopyByteCount > 0) {
			void *writePtr = buffer + (empty ? 0 : dataEndOffset + 1);
			memcpy(writePtr, data, directCopyByteCount);
			dataEndOffset += (empty ? directCopyByteCount - 1 : directCopyByteCount);
		}
		
		if (wraparoundByteCount > 0) {
			memcpy(buffer, data + directCopyByteCount, wraparoundByteCount);
			dataEndOffset = wraparoundByteCount - 1;
		}
		
		if (writableByteCount > 0)
			empty = NO;
		
		return writableByteCount;
	}
}

-(NSUInteger)readDataOfLength:(NSUInteger)desiredLength intoAllocatedBuffer:(void **)outBuffer {
	
	if (outBuffer == NULL || desiredLength == 0)
		return 0;
	
    NSUInteger usedBufferSpace = self.length;
    
	@synchronized(self) {
		
		if (usedBufferSpace == 0) {
			return 0;
		}
		
		NSUInteger readableByteCount = MIN(usedBufferSpace, desiredLength);
		NSUInteger directCopyByteCount = MIN(readableByteCount, self.maximumLength - dataStartOffset);
		NSUInteger wraparoundByteCount = readableByteCount - directCopyByteCount;
		
		void *destinationBuffer = *outBuffer;
		
		if (directCopyByteCount > 0) {
			memcpy(destinationBuffer, buffer + dataStartOffset, directCopyByteCount);
			dataStartOffset += directCopyByteCount;
		}
		
		if (wraparoundByteCount > 0) {
			memcpy(destinationBuffer + directCopyByteCount, buffer, wraparoundByteCount);
			dataStartOffset = wraparoundByteCount;
		}
		
		return readableByteCount;
	}
	
}

-(NSUInteger)length {
	// Length is the distance between the start offset (start of the data)
	// and the end offset (end).
	@synchronized(self) {
		if (dataStartOffset == dataEndOffset) {
			// Empty!
			return 0;
		} else if (dataEndOffset > dataStartOffset) {
			return dataEndOffset - dataStartOffset;
		} else {
			return (maximumLength - dataStartOffset) + dataEndOffset;
		}
	}
}

@synthesize maximumLength;

- (void)dealloc {
	@synchronized(self) {
		memset(buffer, 0, maximumLength);
		free(buffer);
	}
}

@end
