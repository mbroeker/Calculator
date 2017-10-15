//
//  KeychainWrapper.h
//  imported into iBroker
//
//  Created by Chris Lowe on 10/31/11.
//  Copyright (c) 2011 USAA. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Simplified Keychain Management
 *
 * @author      Chris Lowe
 * @copyright   Copyright (C) 2011 USAA
 *
 * @author      Markus Bröker<broeker.markus@googlemail.com>
 * @copyright   Copyright (C) 2017 4customers UG
 */
@interface KeychainWrapper : NSObject

/**
 *
 * @param identifier NSString*
 * @return NSData*
 */
+ (NSData *)searchKeychainCopyMatchingIdentifier:(NSString *)identifier;

/**
 *
 * @param identifier NSString*
 * @return NSString*
 */
+ (NSString *)keychainStringFromMatchingIdentifier:(NSString *)identifier;

/**
 *
 * @param value NSString*
 * @param identifier NSString*
 * @return BOOL
 */
+ (BOOL)createKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier;

/**
 *
 * @param value NSString*
 * @param identifier NSString*
 * @return BOOL
 */
+ (BOOL)updateKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier;

/**
 *
 * @param identifier NSString*
 */
+ (void)deleteItemFromKeychainWithIdentifier:(NSString *)identifier;

/**
 *
 * @param identifier NSString*
 * @return NSDictionary*
 */
+ (NSDictionary *)keychain2ApiKeyAndSecret:(NSString *)identifier;

@end
