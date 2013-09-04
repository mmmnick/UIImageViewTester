// UIImageView+AFNetworking.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "UIImageView+AFNetworking.h"

@interface AFImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
- (void)beginImageAccessForKey:(NSString *)cacheKey;
- (void)endImageAccessForKey:(NSString *)cacheKey;
@end

static inline NSString * AFImageCacheKeyFromURLRequest(NSURLRequest *request);

#pragma mark -

static char kAFImageRequestOperationObjectKey;
static char kAFImagePurgeableDataCacheKeyKey;

@interface UIImageView (_AFNetworking)
@property (readwrite, nonatomic, strong, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
@property (readwrite, nonatomic, strong, setter = af_setPurgeableDataCacheKey:) NSString *af_purgeableDataCacheKey;
@end

@implementation UIImageView (_AFNetworking)
@dynamic af_imageRequestOperation;
@dynamic af_purgeableDataCacheKey;
@end

#pragma mark -

@implementation UIImageView (AFNetworking)

- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}

- (void)af_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)af_purgeableDataCacheKey {
    return (NSString *)objc_getAssociatedObject(self, &kAFImagePurgeableDataCacheKeyKey);
}

- (void)af_setPurgeableDataCacheKey:(NSString *)cacheKey {
    objc_setAssociatedObject(self, &kAFImagePurgeableDataCacheKeyKey, cacheKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_af_imageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_af_imageRequestOperationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    });

    return _af_imageRequestOperationQueue;
}

+ (AFImageCache *)af_sharedImageCache {
    static AFImageCache *_af_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _af_imageCache = [[AFImageCache alloc] init];
        [_af_imageCache setCountLimit:200];
    });

    return _af_imageCache;
}

+ (void)clearSharedImageCache {
    [self.af_sharedImageCache removeAllObjects];
}

#pragma mark -

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{

    [self endImageAccess];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];

    self.af_purgeableDataCacheKey =
    AFImageCacheKeyFromURLRequest(urlRequest);

    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }

        self.af_imageRequestOperation = nil;
    } else {
        if (placeholderImage) {
            self.image = placeholderImage;
        }

        AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                if (success) {
                    success(operation.request, operation.response, responseObject);
                } else if (responseObject) {
                    self.image = responseObject;
                }

                if (self.af_imageRequestOperation == operation) {
                    self.af_imageRequestOperation = nil;
                }
            }

            [[[self class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                if (failure) {
                    failure(operation.request, operation.response, error);
                }

                if (self.af_imageRequestOperation == operation) {
                    self.af_imageRequestOperation = nil;
                }
            }
        }];

        self.af_imageRequestOperation = requestOperation;

        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}

- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
    self.af_imageRequestOperation = nil;
}

- (void)endImageAccess {

    NSString *cacheKey = self.af_purgeableDataCacheKey;
    if (cacheKey != nil) {
        [[[self class] af_sharedImageCache] endImageAccessForKey:cacheKey];
    }
}

- (void)beginImageAccess {

    NSString *cacheKey = self.af_purgeableDataCacheKey;
    if (cacheKey != nil) {
        [[[self class] af_sharedImageCache] beginImageAccessForKey:cacheKey];
    }
}

@end

#pragma mark -

@interface AFPurgeableImage : NSObject <NSDiscardableContent> {

    int32_t _accessCount;
}

@property (nonatomic, strong) UIImage *image;

@end

@implementation AFPurgeableImage

- (BOOL)beginContentAccess {
    _accessCount++;
    return YES;
}

- (void)endContentAccess {
    _accessCount = MAX(0, _accessCount-1);
}

- (void)discardContentIfPossible {
    if (_accessCount <= 0) {
        self.image = nil;
    }
}

- (BOOL)isContentDiscarded {
    return self.image == nil;
}

@end

#pragma mark -

static inline NSString * AFImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation AFImageCache

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

    AFPurgeableImage *wrapper =
    [self objectForKey:AFImageCacheKeyFromURLRequest(request)];
    [wrapper beginContentAccess];

    return wrapper.image;
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    if (image && request) {

        NSString *cacheKey =
        AFImageCacheKeyFromURLRequest(request);

        NSObject <NSDiscardableContent> *discardableContent =
        [self objectForKey:cacheKey];

        [discardableContent endContentAccess];

        AFPurgeableImage *wrapper = [[AFPurgeableImage alloc] init];
        wrapper.image = image;
        [wrapper beginContentAccess];

        [self setObject:wrapper forKey:AFImageCacheKeyFromURLRequest(request)];
    }
}

- (void)beginImageAccessForKey:(NSString *)cacheKey {
    [[self objectForKey:cacheKey] beginContentAccess];
}

- (void)endImageAccessForKey:(NSString *)cacheKey {

    NSObject <NSDiscardableContent> *discardableContent =
    [self objectForKey:cacheKey];

    [discardableContent endContentAccess];
}

@end

#endif
