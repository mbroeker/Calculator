//
//  Calculator+Trading.m
//  Calculator
//
//  Created by Markus Bröker on 15.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator+Trading.h"
#import "Helper.h"

#define WITH_CHECKPOINT_UPDATE NO

@implementation Calculator (Trading)

/**
 * Berechnet die realen Preise anhand des Handelsvolumens auf DEFAULT_EXCHANGE
 *
 * @return NSDictionary*
 */
- (NSDictionary *)realPrices {
    NSDebug(@"Calculator::realprices");

    NSMutableDictionary *volumes = [[NSMutableDictionary alloc] init];

    for (id key in self.currentRatings) {
        double base = [key[DEFAULT_BASE_VOLUME] doubleValue];
        double quote = [key[DEFAULT_QUOTE_VOLUME] doubleValue];

        volumes[key] = @{
            @"in": @(base),
            @"out": @(quote)
        };
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

    for (id key in volumes) {
        if ([key isEqualToString:ASSET_KEY]) {
            continue;
        }

        double v1 = [volumes[key][@"in"] doubleValue];
        double v2 = [volumes[key][@"out"] doubleValue];

        double realPrice = v1 / v2;
        double price = [self btcPriceForAsset:key];
        double percentChange = ((price / realPrice) - 1) * 100.0;

        result[key] = @{
            RP_REALPRICE: @(realPrice),
            RP_PRICE: @(price),
            RP_CHANGE: @(percentChange)
        };
    }

    return result;
}

/**
 * Simple Changes
 *
 * @return NSDictionary*
 */
- (NSDictionary *)realChanges {
    NSDebug(@"Calculator::realChanges");

    NSDictionary *realPrices = [self realPrices];
    NSMutableDictionary *changes = [[NSMutableDictionary alloc] init];

    for (id key in realPrices) {
        changes[key] = [realPrices[key] objectForKey:RP_CHANGE];
    }

    return changes;
}

/**
 * Automatisches Kaufen von Assets
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @return NSString*
 */
- (NSString *)autoBuy:(NSString *)cAsset amount:(double)wantedAmount {
    return [self autoBuy:cAsset amount:wantedAmount withRate:0.0];
}

/**
 * Automatisches Kaufen von Assets
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @param wantedRate double
 * @return NSString*
 */
- (NSString *)autoBuy:(NSString *)cAsset amount:(double)wantedAmount withRate:(double)wantedRate {
    if ([self balance:ASSET_KEY] < 0.00050000) {
        return nil;
    }

    if ([cAsset isEqualToString:self.masterKey]) {
        // Illegale Kombination
        return nil;
    }

    NSDebug(@"Calculator::autoBuy:%@ amount:%8f withRate:%.8f => %.8f BTC", cAsset, wantedAmount, wantedRate, [self balance:ASSET_KEY]);

    double feeAsFactor = 1.0;

    NSString *defaultExchange = [self defaultExchange];
    if ([defaultExchange isEqualToString:EXCHANGE_BITTREX]) {
        feeAsFactor = 0.9975;
    }

    NSMutableDictionary *currentRatings = [self currentRatings];

    double btcPrice = [currentRatings[self.masterKey] doubleValue];
    double assetPrice = [currentRatings[cAsset] doubleValue];
    double cRate = wantedRate;

    if (cRate == 0.0) {
        cRate = assetPrice;
    }

    // Bestimme die maximale Anzahl an ASSET_KEY's, die verkauft werden können...
    double amountMax = feeAsFactor * ([self balance:ASSET_KEY] / cRate);
    double amount = amountMax;

    if (wantedAmount > 0) {
        amount = wantedAmount;
    }

    // Es kann maximal für amountMax gekauft werden...
    if (amount > amountMax) {
        NSString *mText = @"Not enough BTC";
        NSString *iText = @"You do not have enough BTC for this trade";
        [Helper notificationText:mText info:iText];
        return nil;
    }

    // Sollte einer dieser Beträge negativ sein, wird die Transaktion verhindert
    if (amount <= 0 || btcPrice <= 0 || assetPrice <= 0 || cRate <= 0) {
        NSString *mText = @"Not enough BTC";
        NSString *iText = @"You do not have enough BTC for this trade";
        [Helper notificationText:mText info:iText];
        return nil;
    }

    NSString *assetKey = [cAsset componentsSeparatedByString:@"_"][1];
    NSString *text = [NSString stringWithFormat:@"Buy %.4f %@ for %.8f each", amount, assetKey, cRate];

    // Bei 0 gibts eine Kaufbestätigung, bei < 0 wird instant gekauft
    if (wantedAmount >= 0) {
        __block BOOL abort = NO;
        dispatch_sync(dispatch_get_main_queue(), ^() {
            if ([Helper messageText:@"ORDER CONFIRMATION" info:text] == NSAlertFirstButtonReturn) {
                abort = YES;
            }
        });

        if (abort) { return nil; }
    }

    NSDictionary *apiKey = [self apiKey];
    if (!apiKey) {
        return nil;
    }

    id <ExchangeProtocol> exchange = [self exchange];
    NSDictionary *order = [exchange buy:apiKey currencyPair:cAsset amount:amount rate:cRate];

    if (order[DEFAULT_ERROR]) {
        [Helper notificationText:@"Error" info:order[DEFAULT_ERROR]];
        return nil;
    }

    if (order[DEFAULT_ORDER_NUMBER]) {
        if (WITH_CHECKPOINT_UPDATE) {
            [self updateCheckpointForAsset:cAsset withBTCUpdate:YES andRate:cRate];
        }

        return order[DEFAULT_ORDER_NUMBER];
    }

    return nil;
}

/**
 * Automatisches Verkaufen von Assets
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @return NSString*
 */
- (NSString *)autoSell:(NSString *)cAsset amount:(double)wantedAmount {
    return [self autoSell:cAsset amount:wantedAmount withRate:0.0];
}

/**
 * Automatisches Verkaufen von Assets
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @param wantedRate double
 * @return NSString*
 */
- (NSString *)autoSell:(NSString *)cAsset amount:(double)wantedAmount withRate:(double)wantedRate {

    if ([cAsset isEqualToString:self.masterKey]) {
        // Illegale Kombination
        return nil;
    }

    NSDebug(@"Calculator::autoSell:%@ amount:%8f withRate:%.8f", cAsset, wantedAmount, wantedRate);

    double feeAsFactor = 1.0;

    NSString *defaultExchange = [self defaultExchange];
    if ([defaultExchange isEqualToString:EXCHANGE_BITTREX]) {
        //feeAsFactor = 0.9975;
    }

    NSMutableDictionary *currentRatings = [self currentRatings];

    NSString *assetKey = [cAsset componentsSeparatedByString:@"_"][1];

    // Bestimme die maximale Anzahl an Assets, die verkauft werden können...
    double amountMax = feeAsFactor * [self balance:assetKey];
    double amount = amountMax;

    double btcPrice = [currentRatings[self.masterKey] doubleValue];
    double assetPrice = [currentRatings[cAsset] doubleValue];

    if (wantedAmount > 0) {
        amount = wantedAmount;
    }

    double cRate = wantedRate;

    if (cRate == 0.0) {
        cRate = assetPrice;
    }

    // DUST TRADE 50k Satoshi
    if (([self balance:assetKey] * cRate) < 0.00050000) { return nil; }

    // Sollte einer dieser Beträge negativ sein, wird die Transaktion verhindert
    if (amount > amountMax || amount <= 0 || btcPrice <= 0 || assetPrice <= 0 || cRate <= 0) {
        NSString *mText = [NSString stringWithFormat:@"Not enough %@", cAsset];
        NSString *iText = [NSString stringWithFormat:@"You do not have enough %@ for this trade", cAsset];
        [Helper notificationText:mText info:iText];
        return nil;
    }

    NSString *text = [NSString stringWithFormat:@"Sell %.4f %@ for %.8f each", amount, assetKey, cRate];


    // Bei 0 gibts eine Verkaufsbestätigung, bei < 0 wird instant gekauft
    if (wantedAmount >= 0) {
        __block BOOL abort = NO;
        dispatch_sync(dispatch_get_main_queue(), ^() {
            if ([Helper messageText:@"ORDER CONFIRMATION" info:text] == NSAlertFirstButtonReturn) {
                abort = YES;
            }
        });

        if (abort) { return nil; }
    }

    NSDictionary *apiKey = [self apiKey];
    if (apiKey == nil) {
        return nil;
    }

    id <ExchangeProtocol> exchange = [self exchange];
    NSDictionary *order = [exchange sell:apiKey currencyPair:cAsset amount:amount rate:cRate];

    if (order[DEFAULT_ERROR]) {
        [Helper notificationText:@"Error" info:order[DEFAULT_ERROR]];
        return nil;
    }

    if (order[DEFAULT_ORDER_NUMBER]) {
        if (WITH_CHECKPOINT_UPDATE) {
            [self updateCheckpointForAsset:cAsset withBTCUpdate:NO andRate:cRate];
        }

        return order[DEFAULT_ORDER_NUMBER];
    }

    return nil;
}

/**
 * Automatisches Kaufen...
 *
 * @param cAsset NSString*
 */
- (void)autoBuyAll:(NSString *)cAsset {
    NSDebug(@"Calculator::autoBuyAll:%@", cAsset);

    static NSString *lastBoughtAsset = @"";

    double ask = ([[self tradingWithConfirmation] boolValue]) ? 0 : -1;
    if ([cAsset isEqualToString:lastBoughtAsset]) {
        // ask = 0;
    }

    if ([self autoBuy:cAsset amount:ask] != nil) {
        lastBoughtAsset = cAsset;
    }
}

/**
 * Automatisches Verkaufen...
 *
 * @param cAsset NSString*
 */
- (void)autoSellAll:(NSString *)cAsset {
    NSDebug(@"Calculator::autoSellAll:%@", cAsset);

    double ask = ([[self tradingWithConfirmation] boolValue]) ? 0 : -1;

    [self autoSell:cAsset amount:ask];
}

/**
 * Verkaufe Altcoins, die im Wert um "wantedEuros" gestiegen ist
 *
 * @param wantedEuros double
 */
- (void)sellWithProfitInEuro:(double)wantedEuros {
    NSDebug(@"Calculator::sellWithProfitInEuro:%.4f", wantedEuros);

    for (id key in self.currentRatings) {
        if ([key isEqualToString:self.masterKey]) { continue; }

        NSString *currentKey = [key componentsSeparatedByString:@"_"][1];
        NSDictionary *checkpoint = [self checkpointForAsset:key];

        double initialPrice = [checkpoint[CP_INITIAL_PRICE] doubleValue];
        double currentPrice = [checkpoint[CP_CURRENT_PRICE] doubleValue];

        double initialBalanceInEUR = [self btc2Fiat:initialPrice * [self balance:currentKey]];
        double currentBalanceInEUR = [self btc2Fiat:currentPrice * [self balance:currentKey]];

        double gain = currentBalanceInEUR - initialBalanceInEUR;

        if (gain > wantedEuros) {
            [self autoSellAll:key];
        }
    }
}

/**
 * Verkaufe Altcoins, deren Exchange-Rate um "wantedPercent" Prozent gestiegen ist...
 *
 * @param wantedPercent double
 */
- (void)sellWithProfitInPercent:(double)wantedPercent {
    NSDebug(@"Calculator::sellWithProfitInPercent:%.4f %%", wantedPercent);

    for (id key in self.currentRatings) {
        if ([key isEqualToString:self.masterKey]) { continue; }

        NSString *currentKey = [key componentsSeparatedByString:@"_"][1];
        NSDictionary *checkpoint = [self checkpointForAsset:key];
        NSDictionary *btcCheckpoint = [self checkpointForAsset:self.masterKey];

        double currentPrice = [checkpoint[CP_CURRENT_PRICE] doubleValue];
        double btcPercent = [btcCheckpoint[CP_PERCENT] doubleValue];
        double percent = [checkpoint[CP_PERCENT] doubleValue];

        double effectiveBTCPercent = percent - btcPercent;
        double amount = currentPrice * [self balance:currentKey];

        // DUST TRADE 50k Satoshi
        if (amount < 0.00050000) { continue; }

        // Security Feature: We want more, not less
        if (effectiveBTCPercent < 0) {
            continue;
        }

        if ((effectiveBTCPercent > wantedPercent)) {
            [self autoSellAll:key];
        }
    }
}

/**
 * Verkaufe Assets mit einer Investor-Rate von "wantedPercent"% oder mehr...
 *
 * @param wantedPercent double
 */
- (void)sellByInvestors:(double)wantedPercent {
    NSDebug(@"Calculator::sellByInvestors:%.4f %%", wantedPercent);

    NSDictionary *currencyUnits = [self realChanges];
    NSNumber *lowest = [[currencyUnits allValues] valueForKeyPath:@"@min.self"];

    if (lowest != nil) {
        NSString *lowestKey = [currencyUnits allKeysForObject:lowest][0];
        double investorsRate = [currencyUnits[lowestKey] doubleValue];

        NSString *assetKey = [lowestKey componentsSeparatedByString:@"_"][1];
        double amount = [self balance:assetKey] * [self btcPriceForAsset:lowestKey];

        // DUST TRADE 50k Satoshi
        if (amount < 0.00050000) { return; }

        // Verkaufe auf Grundlage der aktuellen Investoren-Rate
        if (investorsRate < wantedPercent) {
            [self autoSellAll:lowestKey];
        }
    }
}

/**
 * Kaufe Altcoins, deren Exchange-Rate um "wantedPercent" Prozent gestiegen ist...
 *
 * @param wantedPercent double
 * @param wantedRate double
 */
- (void)buyWithProfitInPercent:(double)wantedPercent andInvestmentRate:(double)wantedRate {
    NSDebug(@"Calculator::buyWithProfitInPercent:%.4f %% andRate:%.8f", wantedPercent, wantedRate);

    double balance = [self balance:ASSET_KEY];
    NSDictionary *realChanges = [self realChanges];

    if (balance < 0.00050000) { return; }

    for (id key in self.currentRatings) {
        if ([key isEqualToString:self.masterKey]) { continue; }

        NSString *currentKey = [NSString stringWithFormat:@"%@_%@", ASSET_KEY, key];
        NSDictionary *btcCheckpoint = [self checkpointForAsset:self.masterKey];
        NSDictionary *checkpoint = [self checkpointForAsset:currentKey];

        double btcPercent = [btcCheckpoint[CP_PERCENT] doubleValue];
        double percent = [checkpoint[CP_PERCENT] doubleValue];

        double effectivePercent = btcPercent - percent;
        double realChange = [realChanges[key] doubleValue];

        // Security Feature: We want more, not less
        if (effectivePercent < 0) {
            continue;
        }

        // Trade only with a higher Price/Volume Ratio
        if (wantedRate > realChange) {
            continue;
        }

        if (effectivePercent > wantedPercent) {
            [self autoBuyAll:key];
        }
    }
}

/**
 * Kaufe Assets mit einer Investor-Rate von "rate"% oder mehr...
 *
 * @param wantedRate double
 */
- (void)buyByInvestors:(double)wantedRate {
    NSDebug(@"Calculator::buyByInvestors:%.4f %%", wantedRate);

    NSDictionary *currencyUnits = [self realChanges];

    NSNumber *highest = [[currencyUnits allValues] valueForKeyPath:@"@max.self"];

    if (highest != nil) {
        NSString *highestKey = [currencyUnits allKeysForObject:highest][0];
        double investorsRate = [currencyUnits[highestKey] doubleValue];

        // Kaufe auf Grundlage der aktuellen Investoren-Rate
        if (investorsRate > wantedRate) {
            [self autoBuyAll:highestKey];
        }
    }
}

/**
 * buyTheBest: Kaufe blind die am höchsten bewertete Asset
 *
 */
- (void)buyTheBest {
    NSDebug(@"Calculator::buyTheBest");

    NSDictionary *currencyUnits = [self checkpointChanges];
    NSNumber *highest = [[currencyUnits allValues] valueForKeyPath:@"@max.self"];

    if (highest != nil) {
        NSString *highestKey = [currencyUnits allKeysForObject:highest][0];
        [self autoBuyAll:highestKey];
    }
}

/**
 * buyTheWorst: Kaufe blind die am niedrigsten bewertete Asset
 *
 */
- (void)buyTheWorst {
    NSDebug(@"Calculator::buyTheWorst");

    NSDictionary *currencyUnits = [self checkpointChanges];
    NSNumber *lowest = [[currencyUnits allValues] valueForKeyPath:@"@min.self"];

    if (lowest != nil) {
        NSString *lowestKey = [currencyUnits allKeysForObject:lowest][0];
        [self autoBuyAll:lowestKey];
    }
}

@end
