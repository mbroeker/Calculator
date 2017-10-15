//
//  Calculator.h
//  Calculator
//
//  Created by Markus Bröker on 11.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Brokerage/Brokerage.h>
#import "CalculatorConstants.h"

/**
 * Calculator for Crypto Currencies
 *
 * @author      Markus Bröker<broeker.markus@googlemail.com>
 * @copyright   Copyright (C) 2017 4customers UG
 */
@interface Calculator : NSObject

@property NSNumber *tradingWithConfirmation;

/**
 * Static Constructor implemented as singleton
 *
 * @return id
 */
+ (id)instance;

/**
 * Static Constructor implemented as singleton
 *
 * @param currencies NSArray*
 * @return id
 */
+ (id)instance:(NSArray *)currencies;

/**
 * Update the balance for a given asset
 *
 * @param asset (NSString *)
 * @param newBalance double
 */
- (void)updateBalance:(NSString *)asset withBalance:(double)newBalance;

/**
 * Update the balance
 *
 * @param newBalance (NSDictionary *)
 */
- (void)updateBalances:(NSDictionary *)newBalance;

/**
 * Update the current Ratings
 *
 */
- (void)updateRatings;

/**
 * Sums up the current balances of all cryptos in Fiat-Money (EUR, USD, GBP, JPY, CNY)
 *
 * @param currency NSString*
 * @return double
 */
- (double)calculate:(NSString *)currency;

/**
 * Sums up the current balances of all cryptos in Fiat-Money (EUR, USD, GBP, JPY, CNY) with specific ratings
 *
 * @param ratings
 * @param currency NSString*
 * @return double
 */
- (double)calculateWithRatings:(NSDictionary *)ratings currency:(NSString *)currency;

/**
 * Calculate the BTC Price for the given ASSET
 *
 * @param asset NSString*
 * @return double
 */
- (double)btcPriceForAsset:(NSString *)asset;

/**
 * Calculate the FIAT Price for the given ASSET with current settings(EUR, USD, GBP, CNY, JPY)
 *
 * @param asset NSString*
 * @return double
 */
- (double)fiatPriceForAsset:(NSString *)asset;

/**
 * Calculate the current exchange factor for the given ASSET in relation to another asset
 *
 * @param asset NSString*
 * @param baseAsset NSString*
 * @return double
 */
- (double)factorForAsset:(NSString *)asset inRelationTo:(NSString *)baseAsset;

/**
 * Calculate the BTC Price from a given FiatPrice
 *
 * @param fiatPrice double
 * @return double
 */
- (double)fiat2BTC:(double)fiatPrice;

/**
 * Calculate the Fiat Price from a given BTC Price
 *
 * @param fiatPrice double
 * @return double
 */
- (double)btc2Fiat:(double)btcPrice;

/**
 * Retrieve the currently active Fiat-Currency-Pair (EUR/USD) or (USD/EUR) ...
 *
 * @return NSArray*
 */
- (NSArray *)fiatCurrencies;

/**
 * Get a reference to the broker
 *
 * @return Broker
 */
- (id)broker;

/**
 * Switch to another Exchange
 *
 * @param exchangeKey NSString* EXCHANGE_BITTREX | EXCHANGE_POLONIEX
 * @param update BOOL Instantly refresh the ticker keys
 */
- (void)exchange:(NSString *)exchangeKey withUpdate:(BOOL)update;

/**
 * Return the current active exchange as id<ExchangeProtocol>
 *
 * @return id<ExchangeProtocol>
 */
- (id <ExchangeProtocol>)exchange;

/**
 * Return the currently active exchange as string
 *
 * @return NSString*
 */
- (NSString *)defaultExchange;

/**
 * Return the TickerData
 *
 * @return NSDictionary*
 */
- (NSDictionary *)tickerDictionary;

/**
 * Return the current Balances
 *
 * @return NSMutableDictionary*
 */
- (NSMutableDictionary *)balances;

/**
 * Return the current Balances
 *
 * @param asset
 * @return double
 */
- (double)balance:(NSString *)asset;

/**
 * Get the initial ratings
 * @return NSDictionary*
 */
- (NSMutableDictionary *)initialRatings;

/**
 * Get current Ratings
 * @return NSDictionary*
 */
- (NSMutableDictionary *)currentRatings;

/**
 * Minimize access to the Keychain
 */
- (NSDictionary *)apiKey;

/**
 * Reset the app
 */
+ (void)reset;

@end

#import "Calculator+Checkpoints.h"
#import "Calculator+Trading.h"
