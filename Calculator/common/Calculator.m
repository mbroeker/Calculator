//
//  Calculator.m
//  Calculator
//
//  Created by Markus Bröker on 11.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator.h"

@implementation Calculator {
    NSMutableDictionary *initialRatings;
    NSMutableDictionary *currentRatings;
    NSMutableDictionary *balance;

    // Ticker Mapping
    NSDictionary *tickerKeys;
    NSDictionary *tickerKeysDescription;

    NSArray *fiatCurrencies;
}

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

        balance = [[defaults objectForKey:KEY_CURRENT_BALANCE] mutableCopy];

        if (balance == nil) {
            balance = [@{
                ASSET_KEY(1): @0.0,
                ASSET_KEY(2): @0.0,
                ASSET_KEY(3): @0.0,
                ASSET_KEY(4): @0.0,
                ASSET_KEY(5): @0.0,
                ASSET_KEY(6): @0.0,
                ASSET_KEY(7): @0.0,
                ASSET_KEY(8): @0.0,
                ASSET_KEY(9): @0.0,
                ASSET_KEY(10): @0.0,
            } mutableCopy];

            [defaults setObject:balance forKey:KEY_CURRENT_BALANCE];
        }

        tickerKeys = @{
            ASSET_KEY(1): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), fiatCurrencies[0]],
            ASSET_KEY(2): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(2)],
            ASSET_KEY(3): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(3)],
            ASSET_KEY(4): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(4)],
            ASSET_KEY(5): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(5)],
            ASSET_KEY(6): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(6)],
            ASSET_KEY(7): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(7)],
            ASSET_KEY(8): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(8)],
            ASSET_KEY(9): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(9)],
            ASSET_KEY(10): [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), ASSET_KEY(10)],
        };

        tickerKeysDescription = @{
            ASSET_DESC(1): ASSET_KEY(1),
            ASSET_DESC(2): ASSET_KEY(2),
            ASSET_DESC(3): ASSET_KEY(3),
            ASSET_DESC(4): ASSET_KEY(4),
            ASSET_DESC(5): ASSET_KEY(5),
            ASSET_DESC(6): ASSET_KEY(6),
            ASSET_DESC(7): ASSET_KEY(7),
            ASSET_DESC(8): ASSET_KEY(8),
            ASSET_DESC(9): ASSET_KEY(9),
            ASSET_DESC(10): ASSET_KEY(10),
        };

        [defaults synchronize];

        [self updateRatings];
    }

    return self;
}

/**
 * Update the ratings
 *
 * @param asset NSString*
 * @return double
 */
- (void)updateRatings {
    dispatch_queue_t updateQueue = dispatch_queue_create("de.4customers.calculator.updateRatings", nil);
    dispatch_sync(updateQueue, ^{
        NSDictionary *tickerDictionary = [Bittrex ticker:fiatCurrencies];

        currentRatings = [[NSMutableDictionary alloc] init];

        for (id key in tickerKeys) {
            currentRatings[key] = tickerDictionary[tickerKeys[key]][DEFAULT_LAST];
        }
    });
}

/**
 * Update the balance for a given asset
 *
 * @param asset (NSString *)
 * @param newBalance double
 */
- (void)updateBalance:(NSString *)asset withBalance:(double) newBalance {
    balance[asset] = [NSNumber numberWithDouble:newBalance];
}

/**
 * Update the balance
 *
 * @param newBalance (NSDictionary *)
 */
- (void)updateBalances:(NSDictionary *)newBalance {
    balance = [newBalance mutableCopy];
}

/**
 * Return the current BTC Price for a given ASSET
 *
 * @param asset NSString*
 * @return double
 */
- (double)btcPriceForAsset:(NSString *)asset {
    NSDebug(@"Calculator::btcPriceForAsset:%@", asset);

    if ([asset isEqualToString:ASSET_KEY(1)]) { return 1; }
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

    double fiatPrice = [currentRatings[ASSET_KEY(1)] doubleValue];
    double assetPrice = [self btcPriceForAsset:asset];

    if ([asset isEqualToString:ASSET_KEY(1)]) {
        return fiatPrice;
    }

    return fiatPrice * assetPrice;
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

    double asset1Rating = [ratings[ASSET_KEY(1)] doubleValue];
    double asset2Rating = [ratings[ASSET_KEY(2)] doubleValue];
    double asset3Rating = [ratings[ASSET_KEY(3)] doubleValue];
    double asset4Rating = [ratings[ASSET_KEY(4)] doubleValue];
    double asset5Rating = [ratings[ASSET_KEY(5)] doubleValue];

    double asset6Rating = [ratings[ASSET_KEY(6)] doubleValue];
    double asset7Rating = [ratings[ASSET_KEY(7)] doubleValue];
    double asset8Rating = [ratings[ASSET_KEY(8)] doubleValue];
    double asset9Rating = [ratings[ASSET_KEY(9)] doubleValue];
    double asset10Rating = [ratings[ASSET_KEY(10)] doubleValue];

    double price1 = [balance[ASSET_KEY(1)] doubleValue] * asset1Rating;
    double price2 = asset1Rating * [balance[ASSET_KEY(2)] doubleValue] * asset2Rating;
    double price3 = asset1Rating * [balance[ASSET_KEY(3)] doubleValue] * asset3Rating;
    double price4 = asset1Rating * [balance[ASSET_KEY(4)] doubleValue] * asset4Rating;
    double price5 = asset1Rating * [balance[ASSET_KEY(5)] doubleValue] * asset5Rating;

    double price6 = asset1Rating * [balance[ASSET_KEY(6)] doubleValue] * asset6Rating;
    double price7 = asset1Rating * [balance[ASSET_KEY(7)] doubleValue] * asset7Rating;
    double price8 = asset1Rating * [balance[ASSET_KEY(8)] doubleValue] * asset8Rating;
    double price9 = asset1Rating * [balance[ASSET_KEY(9)] doubleValue] * asset9Rating;
    double price10 = asset1Rating * [balance[ASSET_KEY(10)] doubleValue] * asset10Rating;

    // prices in eur
    double sum = price1 + price2 + price3 + price4 + price5 + price6 + price7 + price8 + price9 + price10;

    if ([currency isEqualToString:ASSET_KEY(1)]) {
        return sum / asset1Rating;
    }

    return [self fiat2BTC:sum] / [ratings[currency] doubleValue];
}

/**
 * Calculate the BTC Price from a given FiatPrice
 *
 * @param fiatPrice double
 * @return double
 */
- (double)fiat2BTC:(double)fiatPrice {
    double btcPrice = [currentRatings[ASSET_KEY(1)] doubleValue];

    return fiatPrice / btcPrice;
}

/**
 * Calculate the Fiat Price from a given BTC Price
 *
 * @param fiatPrice double
 * @return double
 */
- (double)btc2Fiat:(double)btcPrice {
    double fiatPrice = 1 / [currentRatings[ASSET_KEY(1)] doubleValue];

    return btcPrice / fiatPrice;
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
 * Static Reset-Method for Clean-Up
 *
 */
+ (void)reset {
    NSDebug(@"Calculator::reset");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults removeObjectForKey:KEY_CURRENT_ASSETS];
    [defaults removeObjectForKey:KEY_CURRENT_BALANCE];
    [defaults removeObjectForKey:KEY_FIAT_CURRENCIES];
    [defaults removeObjectForKey:KEY_INITIAL_RATINGS];

    [defaults synchronize];
}

@end
