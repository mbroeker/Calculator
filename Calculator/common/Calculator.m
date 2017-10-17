//
//  Calculator.m
//  Calculator
//
//  Created by Markus Bröker on 11.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator.h"
#import "Helper.h"
#import "KeychainWrapper.h"

@implementation Calculator {

    // The Broker
    Broker *broker;

    // The Exchange to use
    id <ExchangeProtocol> exchange;

    // Exchange User Prefs
    NSString *defaultExchange;

    // Ticker Data
    NSDictionary *tickerDictionary;

    // Common instance vars
    NSArray *fiatCurrencies;
    NSDictionary *keyAndSecret;
}

@synthesize currentRatings;
@synthesize initialRatings;
@synthesize balances;
@synthesize tradingWithConfirmation;

/**
 * Check for inf, nan or zero
 *
 * @param value BOOL
 */
+ (BOOL)zeroNanOrInfinity:(double)value {
    BOOL zeroNanOrInfinity = ((value == 0.0) || isinf(value) || isnan(value));

    return zeroNanOrInfinity;
}

/**
 * The Public Constructor with EUR/USD
 *
 * @return id
 */
+ (id)instance {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSArray *fc = [defaults objectForKey:KEY_FIAT_CURRENCIES];

    // Vorbelegung mit EUR/USD
    if (fc == nil) {
        fc = @[EUR, USD];
    }

    return [Calculator instance:fc];
}

/**
 * The Public Constructor with choosable fiat currencies
 *
 * @param currencies NSArray*
 * @return id
 */
+ (id)instance:(NSArray *)currencies {
    static Calculator *calculator = nil;

    if (calculator == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            calculator = [[Calculator alloc] initWithFiatCurrencies:currencies];
        });
    }

    return calculator;
}

/**
 * The Private Constructor of this class
 *
 * @param currencies NSArray*
 * @return id
 */
- (id)initWithFiatCurrencies:(NSArray *)currencies {
    NSDebug(@"Calculator::initWithFiatCurrencies:%@", currencies);

    if (self = [super init]) {

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        fiatCurrencies = currencies;

        balances = [@{
            ASSET_KEY: @0.0,
        } mutableCopy];

        defaultExchange = [defaults objectForKey:DEFAULT_EXCHANGE];

        if (defaultExchange == nil) {
            defaultExchange = EXCHANGE_BITTREX;
            [defaults setObject:defaultExchange forKey:DEFAULT_EXCHANGE];
        }

        broker = [[Broker alloc] init];
        exchange = [broker exchange:defaultExchange];

        tradingWithConfirmation = [defaults objectForKey:TRADING_WITH_CONFIRMATION];

        if (tradingWithConfirmation == nil) {
            tradingWithConfirmation = [NSNumber numberWithBool:YES];
            [defaults setObject:tradingWithConfirmation forKey:TRADING_WITH_CONFIRMATION];
        }

        [defaults synchronize];

        [self updateRatings];
    }

    return self;
}

/**
 * Update Ratings and Balances
 *
 * @param asset NSString*
 * @return double
 */
- (void)updateRatings {
    dispatch_queue_t updateQueue = dispatch_queue_create("de.4customers.calculator.updateRatings", nil);
    dispatch_sync(updateQueue, ^{
        NSDictionary *tickerData =[exchange ticker:fiatCurrencies];

        // NO DATA - NO UPDATE
        if (tickerData == nil) { return; }

        tickerDictionary = tickerData;
        currentRatings = [[NSMutableDictionary alloc] init];

        for (id key in tickerDictionary) {
            if ([[key componentsSeparatedByString:@"_"][0] isEqualToString:ASSET_KEY]) {
                currentRatings[key] = tickerDictionary[key][DEFAULT_LAST];
            }
        }

        if (initialRatings == nil) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            initialRatings = [[defaults objectForKey:KEY_INITIAL_RATINGS] mutableCopy];
            if (initialRatings == nil) {
                initialRatings = currentRatings;
                [defaults setObject:initialRatings forKey:KEY_INITIAL_RATINGS];

                [defaults synchronize];
            }
        }

        NSMutableDictionary *result = [[exchange balance:[self apiKey]] mutableCopy];
        if (result[DEFAULT_ERROR]) {
            [Helper notificationText:@"Fetching Balance" info:result[DEFAULT_ERROR]];
            return;
        }

        for (id key in result) {
            // Just migrate the response to double and store them back into a number
            double value = [result[key][DEFAULT_AVAILABLE] doubleValue];
            balances[key] = @(value);
        }
    });
}

/**
 * Update the balance for a given asset
 *
 * @param asset (NSString *)
 * @param newBalance double
 */
- (void)updateBalance:(NSString *)asset withBalance:(double)newBalance {
    balances[asset] = [NSNumber numberWithDouble:newBalance];
}

/**
 * Update the balance
 *
 * @param newBalance (NSDictionary *)
 */
- (void)updateBalances:(NSDictionary *)newBalances {
    balances = [newBalances mutableCopy];
}

/**
 * Return the current BTC Price for a given ASSET
 *
 * @param asset NSString*
 * @return double
 */
- (double)btcPriceForAsset:(NSString *)asset {
    NSDebug(@"Calculator::btcPriceForAsset:%@", asset);

    NSString *masterKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, fiatCurrencies[0]];
    if ([asset isEqualToString:masterKey]) { return 1; }
    return [currentRatings[asset] doubleValue];
}

/**
 * Return the ANY2ANY factor for an ASSET in relation to another ASSET
 *
 * @param asset NSString*
 * @param baseAsset NSString*
 * @return double
 */
- (double)factorForAsset:(NSString *)asset inRelationTo:(NSString *)baseAsset {
    NSDebug(@"Calculator::factorForAsset:%@ inRelationTo:%@", asset, baseAsset);

    return [self btcPriceForAsset:baseAsset] / [self btcPriceForAsset:asset];
}

/**
 * Return the FIAT-Price for an ASSET
 *
 * @param asset NSString*
 * @return double
 */
- (double)fiatPriceForAsset:(NSString *)asset {
    NSDebug(@"Calculator::fiatPriceForAsset:%@", asset);

    NSString *masterKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, fiatCurrencies[0]];
    double fiatPrice = [currentRatings[masterKey] doubleValue];
    double assetPrice = [self btcPriceForAsset:asset];

    if ([asset isEqualToString:masterKey]) {
        return fiatPrice;
    }

    return fiatPrice * assetPrice;
}

/**
 * Calculate the BTC Price from a given FiatPrice
 *
 * @param fiatPrice double
 * @return double
 */
- (double)fiat2BTC:(double)fiatPrice {
    NSString *masterKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, fiatCurrencies[0]];
    double btcPrice = [currentRatings[masterKey] doubleValue];

    return fiatPrice / btcPrice;
}

/**
 * Calculate the Fiat Price from a given BTC Price
 *
 * @param fiatPrice double
 * @return double
 */
- (double)btc2Fiat:(double)btcPrice {
    NSString *masterKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, fiatCurrencies[0]];
    double fiatPrice = 1 / [currentRatings[masterKey] doubleValue];

    return btcPrice / fiatPrice;
}

/**
 * Sum up the current balance in CURRENCY
 *
 * @param currency
 * @return double
 */
- (double)calculate:(NSString *)currency {
    return [self calculateWithRatings:currentRatings currency:currency];
}

/**
 * Sum up the current balance in CURRENCY with custom RATINGS
 *
 * @param ratings
 * @param currency
 * @return double
 */
- (double)calculateWithRatings:(NSDictionary *)ratings currency:(NSString *)currency {
    NSDebug(@"Calculator::calculateWithRatings:%@ currency:%@", ratings, currency);

    for (id key in ratings) {
        if ([Calculator zeroNanOrInfinity:[ratings[key] doubleValue]]) {
            NSDebug(@"ERROR IN CALCULATOR: VALUE FOR %@ OUT OF RANGE", key);
            return 0;
        }
    }

    NSString *masterKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, fiatCurrencies[0]];
    double asset1Rating = [ratings[masterKey] doubleValue];
    double price1 = [balances[ASSET_KEY] doubleValue] * asset1Rating;

    double sum = price1;
    for (id key in ratings) {
        if (![key isEqualToString:masterKey]) {
            NSString *asset = [key componentsSeparatedByString:@"_"][1];
            double assetRating = [ratings[key] doubleValue];
            double price = asset1Rating * [balances[asset] doubleValue] * assetRating;

            sum += price;
        }
    }

    if ([currency isEqualToString:masterKey]) {
        return sum / asset1Rating;
    }

    return [self fiat2BTC:sum] / [ratings[currency] doubleValue];
}

/**
 * Returns the currently active fiat-currencies
 *
 * @return NSArray*
 */
- (NSArray *)fiatCurrencies {
    NSDebug(@"Calculator::fiatCurrencies");

    return fiatCurrencies;
}

/**
 * Get a reference to the broker
 *
 * @return Broker
 */
- (id)broker {
    return broker;
}

/**
 * Switch to another Exchange
 *
 * @param exchangeKey (NSString *) EXCHANGE_BITTREX | EXCHANGE_POLONIEX
 * @param update (BOOL) - Instantly refresh the ticker keys
 */
- (void)exchange:(NSString *)exchangeKey withUpdate:(BOOL)update {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    id <ExchangeProtocol> newExchange = [broker exchange:exchangeKey];

    if (newExchange != nil) {
        exchange = newExchange;
        keyAndSecret = nil;
        defaultExchange = exchangeKey;

        [defaults setObject:defaultExchange forKey:DEFAULT_EXCHANGE];
        [defaults synchronize];

        if (update) {
            [self updateRatings];
        }
    }
}

/**
 * Return the current active exchange as id<ExchangeProtocol>
 *
 * @return id<ExchangeProtocol>
 */
- (id <ExchangeProtocol>)exchange {
    return exchange;
}

/**
 * Return the current active exchange as string
 *
 * @return NSString*
 */
- (NSString *)defaultExchange {
    return defaultExchange;
}

/**
 * Get current TickerData
 * @return NSDictionary*
 */
- (NSDictionary *)tickerDictionary {
    return tickerDictionary;
}

/**
 * Get current Balance for asset
 * @return double*
 */
- (double)balance:(NSString *)asset {
    return [balances[asset] doubleValue];
}

/**
 * Minimieren des Zugriffs auf den Schlüsselbund
 */
- (NSDictionary *)apiKey {
    NSDebug(@"Calculator::apiKey");

    if (keyAndSecret == nil) {
        if ([defaultExchange isEqualToString:EXCHANGE_POLONIEX]) {
            keyAndSecret = [KeychainWrapper keychain2ApiKeyAndSecret:@"POLONIEX"];
        }

        if ([defaultExchange isEqualToString:EXCHANGE_BITTREX]) {
            keyAndSecret = [KeychainWrapper keychain2ApiKeyAndSecret:@"BITTREX"];
        }
    }

    return keyAndSecret;
}

/**
 * Static Reset-Method for Clean-Up
 *
 */
+ (void)reset {
    NSDebug(@"Calculator::reset");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults removeObjectForKey:KEY_CURRENT_ASSETS];
    [defaults removeObjectForKey:KEY_CURRENT_BALANCES];
    [defaults removeObjectForKey:KEY_FIAT_CURRENCIES];
    [defaults removeObjectForKey:KEY_INITIAL_RATINGS];

    [defaults synchronize];
}

@end
