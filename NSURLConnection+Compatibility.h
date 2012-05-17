//
//  NSURLConnection+Compatibility.h
//
//  Created by Vinny Coyne on 27/02/2012.
//  Copyright (c) 2012 App Sandwich Limited. All rights reserved.
//  www.appsandwich.com

#import <Foundation/Foundation.h>

@interface NSURLConnection (ASURLConnection_Compatibility)

+ (void)as_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue*) queue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*)) handler;

@end
