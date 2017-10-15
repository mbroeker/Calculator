//
//  KeychainWrapper.m
//  imported into iBroker
//
//  Created by Chris Lowe on 10/31/11.
//  Copyright (c) 2011 USAA. All rights reserved.
//

#import "KeychainWrapper.h"
#import "Calculator.h"

#define BUNDLE @"de.4customers.iBroker"

@implementation KeychainWrapper

/**
 *
 * @param identifier
 * @return NSMutableDictionary*
 */
+ (NSMutableDictionary *)setupSearchDirectoryForIdentifier:(NSString *)identifier {

    // Setup dictionary to access keychain
    NSMutableDictionary *searchDictionary = [[NSMutableDictionary alloc] init];
    // Specify we are using a Password (vs Certificate, Internet Password, etc)
    [searchDictionary setObject:(__bridge id) kSecClassGenericPassword forKey:(__bridge id) kSecClass];

    NSString *uniqueKey = [NSString stringWithFormat:@"%@.%@", BUNDLE, identifier];
    [searchDictionary setObject:uniqueKey forKey:(__bridge id) kSecAttrService];

    // Uniquely identify the account who will be accessing the keychain
    NSData *encodedIdentifier = [identifier dataUsingEncoding:NSUTF8StringEncoding];
    [searchDictionary setObject:encodedIdentifier forKey:(__bridge id) kSecAttrGeneric];
    [searchDictionary setObject:encodedIdentifier forKey:(__bridge id) kSecAttrAccount];

    return searchDictionary;
}

/**
 *
 * @param identifier
 * @return NSData*
 */
+ (NSData *)searchKeychainCopyMatchingIdentifier:(NSString *)identifier {

    NSMutableDictionary *searchDictionary = [self setupSearchDirectoryForIdentifier:identifier];
    // Limit search results to one
    [searchDictionary setObject:(__bridge id) kSecMatchLimitOne forKey:(__bridge id) kSecMatchLimit];

    // Specify we want NSData/CFData returned
    [searchDictionary setObject:(__bridge id) kCFBooleanTrue forKey:(__bridge id) kSecReturnData];

    // Search
    NSData *result = nil;
    CFTypeRef foundDict = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) searchDictionary, &foundDict);

    if (status == noErr) {
        result = (__bridge_transfer NSData *) foundDict;
    } else {
        result = nil;
    }

    return result;
}

/**
 *
 * @param identifier
 * @return NSString*
 */
+ (NSString *)keychainStringFromMatchingIdentifier:(NSString *)identifier {
    NSData *valueData = [self searchKeychainCopyMatchingIdentifier:identifier];
    if (valueData) {
        NSString *value = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
        return value;
    } else {
        return nil;
    }
}

/**
 *
 * @param value
 * @param identifier
 * @return BOOL
 */
+ (BOOL)createKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier {

    NSMutableDictionary *dictionary = [self setupSearchDirectoryForIdentifier:identifier];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    [dictionary setObject:valueData forKey:(__bridge id) kSecValueData];

    // Protect the keychain entry so its only valid when the device is unlocked
    [dictionary setObject:(__bridge id) kSecAttrAccessibleWhenUnlocked forKey:(__bridge id) kSecAttrAccessible];

    // Add
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef) dictionary, NULL);

    // If the Addition was successful, return.  Otherwise, attempt to update existing key or quit (return NO)
    if (status == errSecSuccess) {
        return YES;
    } else if (status == errSecDuplicateItem) {
        return [self updateKeychainValue:value forIdentifier:identifier];
    } else {
        return NO;
    }
}

/**
 *
 *
 * @param value
 * @param identifier
 * @return BOOL
 */
+ (BOOL)updateKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier {

    NSMutableDictionary *searchDictionary = [self setupSearchDirectoryForIdentifier:identifier];
    NSMutableDictionary *updateDictionary = [[NSMutableDictionary alloc] init];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    [updateDictionary setObject:valueData forKey:(__bridge id) kSecValueData];

    // Update
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef) searchDictionary, (__bridge CFDictionaryRef) updateDictionary);

    if (status == errSecSuccess) {
        return YES;
    } else {
        return NO;
    }
}

/**
 *
 *
 * @param identifier
 */
+ (void)deleteItemFromKeychainWithIdentifier:(NSString *)identifier {
    NSMutableDictionary *searchDictionary = [self setupSearchDirectoryForIdentifier:identifier];
    CFDictionaryRef dictionary = (__bridge CFDictionaryRef) searchDictionary;

    //Delete
    SecItemDelete(dictionary);
}

/**
* Get the API-Key/Secret Pair
*
* @param identifier
* @return NSDictionary*
*/
+ (NSDictionary *)keychain2ApiKeyAndSecret:(NSString *)identifier {
    NSString *data = [KeychainWrapper keychainStringFromMatchingIdentifier:identifier];

    if (data != nil) {
        NSArray *parts = [data componentsSeparatedByString:@":"];
        if ([parts count] == 2) {
            NSDictionary *apiKey = @{
                KEY: [parts objectAtIndex:0],
                SECRET: [parts objectAtIndex:1]
            };

            return apiKey;
        }
    }

    return nil;
}

@end
