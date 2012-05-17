//
//  NSURLConnection+Compatibility.m
//
//  Created by Vinny Coyne on 27/02/2012.
//  Copyright (c) 2012 App Sandwich Limited. All rights reserved.
//  www.appsandwich.com
//


#import "NSURLConnection+Compatibility.h"
#import <objc/runtime.h>


#pragma mark - Container

typedef void(^ASURLConnectionContainerHandler)(NSURLResponse *response, NSData *data, NSError *error);

@interface ASURLConnectionContainer : NSObject {
    
@private
    NSMutableData *_data;
    ASURLConnectionContainerHandler _handler;
    NSURLResponse *_response;
    NSError *_error;
    
}

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLResponse *response;

-(id)initWithConnection:(NSURLConnection *)urlConnection completionHandler:(ASURLConnectionContainerHandler)handler;
-(void)setData:(NSData *)data;
-(void)appendData:(NSData *)data;
-(NSData *)data;
-(ASURLConnectionContainerHandler)handler;

@end

@implementation ASURLConnectionContainer

@synthesize connection, response;

-(id)initWithConnection:(NSURLConnection *)urlConnection completionHandler:(ASURLConnectionContainerHandler)handler {
    self = [super init];
    if (self) {
        self.connection = urlConnection;
        _data = [NSMutableData data];
        _handler = [handler copy];
        _response = nil;
        _error = nil;
    }
    return self;
}

-(void)dealloc {
    _handler = NULL;
}

-(void)setData:(NSData *)data {
    [_data setData:data];
}

-(void)appendData:(NSData *)data {
    [_data appendData:data];
}

-(NSData *)data {
    return _data;
}

-(ASURLConnectionContainerHandler)handler {
    return _handler;
}

@end


#pragma mark - Delegate object

@interface ASURLConnectionInternalDelegate : NSObject {
@private
    NSMutableArray *_connectionContainers;
}

-(void)as_addRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*)) handler;

@end

@implementation ASURLConnectionInternalDelegate

-(id)init {
    self = [super init];
    if (self) {
        _connectionContainers = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

-(void)as_addRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*)) handler {
    
    ASURLConnectionContainer *container = [[ASURLConnectionContainer alloc] initWithConnection:[NSURLConnection connectionWithRequest:request delegate:self] completionHandler:handler];
    [_connectionContainers addObject:container];
    
}

#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    for (ASURLConnectionContainer *container in _connectionContainers) {
        
        if (container.connection == connection) {
            
            container.response = response;
            
            break;
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    for (ASURLConnectionContainer *container in _connectionContainers) {
        
        if (container.connection == connection) {
            
            [container appendData:data];
            
            break;
        }
    }
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    ASURLConnectionContainer *containerToRemove = nil;
    
    for (ASURLConnectionContainer *container in _connectionContainers) {
        
        if (container.connection == connection) {
            
            containerToRemove = container;
            
            ASURLConnectionContainerHandler handler = [container handler];
            
            if ((handler != NULL) && (handler != nil))
                handler([container response], [container data], nil);
            
            break;
        }
    }
    
    if (containerToRemove)
        [_connectionContainers removeObject:containerToRemove];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    ASURLConnectionContainer *containerToRemove = nil;
    
    for (ASURLConnectionContainer *container in _connectionContainers) {
        
        if (container.connection == connection) {
            
            containerToRemove = container;
            
            ASURLConnectionContainerHandler handler = [container handler];
            
            if ((handler != NULL) && (handler != nil))
                handler([container response], [container data], error);
            
            break;
        }
    }
    
    if (containerToRemove)
        [_connectionContainers removeObject:containerToRemove];
}

@end



#pragma mark - Category implementation

@interface NSURLConnection (ASURLConnection_Compatibility_Private)

+(BOOL)as_canUseiOS5Methods;
+(id)as_sharedNSURLConnection;
-(void)as_setInternalDelegate;
-(ASURLConnectionInternalDelegate *)as_internalDelegate;

@end

@implementation NSURLConnection (ASURLConnection_Compatibility_Private)

+(BOOL)as_canUseiOS5Methods {
    
    // This is a really lazy way to check for iOS5.x+, but it does the trick.
    return (NSClassFromString(@"NSJSONSerialization") != nil);
}

+(id)as_sharedNSURLConnection {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
        [_sharedObject as_setInternalDelegate];
    });
    return _sharedObject;
}

static char STRING_KEY;

-(void)as_setInternalDelegate {
    ASURLConnectionInternalDelegate *internalDelegate = [[ASURLConnectionInternalDelegate alloc] init];
    objc_setAssociatedObject(self, &STRING_KEY, internalDelegate, OBJC_ASSOCIATION_RETAIN);
}

-(ASURLConnectionInternalDelegate *)as_internalDelegate {
    return (ASURLConnectionInternalDelegate *)objc_getAssociatedObject(self, &STRING_KEY);
}

@end


@implementation NSURLConnection (ASURLConnection_Compatibility)

+ (void)as_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue*) queue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*)) handler {
    
    if ([NSURLConnection as_canUseiOS5Methods]) {
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:handler];
    }
    else {
        
        NSURLConnection *sharedConnection = [NSURLConnection as_sharedNSURLConnection];
        
        ASURLConnectionInternalDelegate *internalDelegate = [sharedConnection as_internalDelegate];
        [internalDelegate as_addRequest:request completionHandler:handler];
    }
    
}

@end