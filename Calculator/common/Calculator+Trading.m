//
//  Calculator+Trading.m
//  Calculator
//
//  Created by Markus Bröker on 15.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator+Trading.h"
#import "Helper.h"

@implementation Calculator (Trading)

/**
 * Berechnet die realen Preise anhand des Handelsvolumens auf DEFAULT_EXCHANGE
 *
 * @return NSDictionary*
 */
- (NSDictionary *)realPrices {
    NSDebug(@"Calculator::realprices");

    NSMutableDictionary *volumes = [[NSMutableDictionary alloc] init];
    NSDictionary *ticker = [self tickerDictionary];

    for (id key in ticker) {
        double base = [key[DEFAULT_BASE_VOLUME] doubleValue];
        double quote = [key[DEFAULT_QUOTE_VOLUME] doubleValue];

        volumes[key] = @{
            @"in": @(base),
            @"out": @(quote)
        };
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

    for (id key in volumes) {
        if ([key isEqualToString:ASSET_KEY(1)]) {
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
    NSDebug(@"Calculator::autoBuy:%@ amount:%8f", cAsset, wantedAmount);

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
    NSDebug(@"Calculator::autoBuy:%@ amount:%8f withRate:%.8f", cAsset, wantedAmount, wantedRate);

    NSDictionary *apiKey = [self apiKey];

    double feeAsFactor = 1.0;

    NSString *defaultExchange = [self defaultExchange];
    if ([defaultExchange isEqualToString:EXCHANGE_BITTREX]) {
        feeAsFactor = 0.9975;
    }

    if (apiKey) {
        return nil;
    }

    NSArray *fiatCurrencies = [self fiatCurrencies];
    NSMutableDictionary *currentRatings = [self currentRatings];

    double btcPrice = [currentRatings[ASSET_KEY(1)] doubleValue];
    double assetPrice = [currentRatings[cAsset] doubleValue];
    double cRate = wantedRate;

    if (cRate == 0.0) {
        cRate = btcPrice / assetPrice;
    }

    // Bestimme die maximale Anzahl an ASSET_KEY(1)'s, die verkauft werden können...
    double amountMax = feeAsFactor * ([self balance:ASSET_KEY(1)] / cRate);
    double amount = amountMax;

    if (wantedAmount > 0) {
        amount = wantedAmount;
    }

    if ([cAsset isEqualToString:ASSET_KEY(1)] || [cAsset isEqualToString:fiatCurrencies[0]] || [cAsset isEqualToString:fiatCurrencies[1]]) {
        // Illegale Kombination ASSET_KEY(1)_(cAsset)
        return nil;
    }

    // Es kann maximal für amountMax gekauft werden...
    if (amount > amountMax) {
        NSString *mText = NSLocalizedString(@"not_enough_btc", @"Zu wenig BTC");
        NSString *iText = NSLocalizedString(@"not_enough_btc_long", @"Sie haben zu wenig BTC zum Kauf");
        [Helper notificationText:mText info:iText];
        return nil;
    }

    // Sollte einer dieser Beträge negativ sein, wird die Transaktion verhindert
    if (amount <= 0 || btcPrice <= 0 || assetPrice <= 0 || cRate <= 0) {
        NSString *mText = NSLocalizedString(@"not_enough_btc", @"Zu wenig BTC");
        NSString *iText = NSLocalizedString(@"not_enough_btc_long", @"Sie haben zu wenig BTC zum Kauf");
        [Helper notificationText:mText info:iText];
        return nil;
    }

    NSString *text = [NSString stringWithFormat:NSLocalizedString(@"buy_with_amount_asset_and_rate", @"Kaufe %.4f %@ für %.8f das Stück"), amount, cAsset, cRate];

    // Bei 0 gibts eine Kaufbestätigung, bei < 0 wird instant gekauft
    if (wantedAmount >= 0) {
        if ([Helper messageText:NSLocalizedString(@"buy_confirmation", "Kaufbestätigung") info:text] != NSAlertFirstButtonReturn) {
            // Abort Buy
            return nil;
        }
    }

    NSString *cPair = [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), cAsset];

    id <ExchangeProtocol> exchange = [self exchange];
    NSDictionary *order = [exchange buy:apiKey currencyPair:cPair amount:amount rate:cRate];

    if (order[DEFAULT_ERROR]) {
        [Helper notificationText:NSLocalizedString(@"error", "Fehler") info:order[DEFAULT_ERROR]];
        return nil;
    }

    if (order[DEFAULT_ORDER_NUMBER]) {
        [self updateCheckpointForAsset:cAsset withBTCUpdate:YES andRate:cRate];

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
    NSDebug(@"Calculator::autoSell:%@ amount:%8f", cAsset, wantedAmount);

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
    NSDebug(@"Calculator::autoSell:%@ amount:%8f withRate:%.8f", cAsset, wantedAmount, wantedRate);

    NSDictionary *apiKey = [self apiKey];

    double feeAsFactor = 1.0;

    NSString *defaultExchange = [self defaultExchange];
    if ([defaultExchange isEqualToString:EXCHANGE_BITTREX]) {
        //feeAsFactor = 0.9975;
    }

    if (apiKey == nil) {
        return nil;
    }

    NSArray *fiatCurrencies = [self fiatCurrencies];
    NSMutableDictionary *currentRatings = [self currentRatings];

    // Bestimme die maximale Anzahl an Assets, die verkauft werden können...
    double amountMax = feeAsFactor * [self balance:cAsset];
    double amount = amountMax;

    double btcPrice = [currentRatings[ASSET_KEY(1)] doubleValue];
    double assetPrice = [currentRatings[cAsset] doubleValue];

    if (wantedAmount > 0) {
        amount = wantedAmount;
    }

    if ([cAsset isEqualToString:ASSET_KEY(1)] || [cAsset isEqualToString:fiatCurrencies[0]] || [cAsset isEqualToString:fiatCurrencies[1]]) {
        // Illegale Kombination ASSET_KEY(1)_(cAsset)
        return nil;
    }

    double cRate = wantedRate;

    if (cRate == 0.0) {
        cRate = btcPrice / assetPrice;
    }

    // Sollte einer dieser Beträge negativ sein, wird die Transaktion verhindert
    if (amount > amountMax || amount <= 0 || btcPrice <= 0 || assetPrice <= 0 || cRate <= 0) {
        NSString *mText = [NSString stringWithFormat:NSLocalizedString(@"not_enough_asset_param", @"Zu wenig %@"), cAsset];
        NSString *iText = [NSString stringWithFormat:NSLocalizedString(@"not_enough_asset_long_param", @"Zu wenig %@ zum Verkaufen"), cAsset];
        [Helper notificationText:mText info:iText];
        return nil;
    }

    NSString *text = [NSString stringWithFormat:NSLocalizedString(@"sell_with_amount_asset_and_rate", @"Verkaufe %.4f %@ für %.8f das Stück"), amount, cAsset, cRate];

    // Bei 0 gibts eine Verkaufsbestätigung, bei < 0 wird instant gekauft
    if (wantedAmount >= 0) {
        if ([Helper messageText:NSLocalizedString(@"sell_confirmation", @"Verkaufsbestätigung") info:text] != NSAlertFirstButtonReturn) {
            // Abort Sell
            return nil;
        }
    }

    NSString *cPair = [NSString stringWithFormat:@"%@_%@", ASSET_KEY(1), cAsset];
    id <ExchangeProtocol> exchange = [self exchange];
    NSDictionary *order = [exchange sell:apiKey currencyPair:cPair amount:amount rate:cRate];

    if (order[DEFAULT_ERROR]) {
        [Helper notificationText:NSLocalizedString(@"error", "Fehler") info:order[DEFAULT_ERROR]];
        return nil;
    }

    if (order[DEFAULT_ORDER_NUMBER]) {
        [self updateCheckpointForAsset:cAsset withBTCUpdate:NO andRate:cRate];

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

        // Aktualisiere alle Checkpoints
        [self updateCheckpointForAsset:DASHBOARD withBTCUpdate:YES];
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
    if ([self autoSell:cAsset amount:ask] != nil) {
        // Aktualisiere alle Checkpoints
        [self updateCheckpointForAsset:DASHBOARD withBTCUpdate:YES];
    }
}

/**
 * Verkaufe Altcoins, die im Wert um "wantedEuros" gestiegen ist
 *
 * @param wantedEuros double
 */
- (void)sellWithProfitInEuro:(double)wantedEuros {
    NSDebug(@"Calculator::sellWithProfitInEuro:%.4f", wantedEuros);

    NSArray *fiatCurrencies = [self fiatCurrencies];
    NSMutableDictionary *balances = [self balances];

    for (id key in balances) {
        if ([key isEqualToString:ASSET_KEY(1)]) { continue; }
        if ([key isEqualToString:fiatCurrencies[0]]) { continue; }
        if ([key isEqualToString:fiatCurrencies[1]]) { continue; }

        NSDictionary *checkpoint = [self checkpointForAsset:key];

        double initialPrice = [checkpoint[CP_INITIAL_PRICE] doubleValue];
        double currentPrice = [checkpoint[CP_CURRENT_PRICE] doubleValue];

        double initialBalanceInEUR = initialPrice * [self balance:key];
        double currentBalanceInEUR = currentPrice * [self balance:key];

        double gain = currentBalanceInEUR - initialBalanceInEUR;

        if (gain > wantedEuros) {
            [self autoSellAll:key];
        }
    }
}

/**
 * Verkaufe Altcoins mit mindestens 1 Euro im Bestand, deren Exchange-Rate um "wantedPercent" Prozent gestiegen ist...
 *
 * @param wantedPercent double
 */
- (void)sellWithProfitInPercent:(double)wantedPercent {
    NSDebug(@"Calculator::sellWithProfitInPercent:%.4f %%", wantedPercent);

    NSArray *fiatCurrencies = [self fiatCurrencies];
    NSMutableDictionary *balances = [self balances];

    for (id key in balances) {
        if ([key isEqualToString:ASSET_KEY(1)]) { continue; }
        if ([key isEqualToString:fiatCurrencies[0]]) { continue; }
        if ([key isEqualToString:fiatCurrencies[1]]) { continue; }

        NSDictionary *checkpoint = [self checkpointForAsset:key];
        NSDictionary *btcCheckpoint = [self checkpointForAsset:ASSET_KEY(1)];

        double currentPrice = [checkpoint[CP_CURRENT_PRICE] doubleValue];
        double btcPercent = [btcCheckpoint[CP_PERCENT] doubleValue];
        double percent = [checkpoint[CP_PERCENT] doubleValue];

        double effectiveBTCPercent = percent - btcPercent;
        double balance = currentPrice * [self balance:key];

        // Security Feature: We want more, not less
        if (effectiveBTCPercent < 0) {
            continue;
        }

        if ((effectiveBTCPercent > wantedPercent) && (balance > 1.0)) {
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

    NSMutableDictionary *balances = [self balances];

    NSNumber *lowest = [[currencyUnits allValues] valueForKeyPath:@"@min.self"];

    if (lowest != nil) {
        NSString *lowestKey = [currencyUnits allKeysForObject:lowest][0];
        double investorsRate = [currencyUnits[lowestKey] doubleValue];

        double price = [balances[lowestKey] doubleValue] * [self btcPriceForAsset:lowestKey];

        // Wir verkaufen keinen Sternenstaub...
        if (price < 0.0001) { return; }

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

    double balance = [self balance:ASSET_KEY(1)];
    NSDictionary *realChanges = [self realChanges];

    if (balance < 0.0001) { return; }

    NSArray *fiatCurrencies = [self fiatCurrencies];
    NSMutableDictionary *balances = [self balances];

    for (id key in balances) {
        if ([key isEqualToString:ASSET_KEY(1)]) { continue; }
        if ([key isEqualToString:fiatCurrencies[0]]) { continue; }
        if ([key isEqualToString:fiatCurrencies[1]]) { continue; }

        NSDictionary *checkpoint = [self checkpointForAsset:key];
        NSDictionary *btcCheckpoint = [self checkpointForAsset:ASSET_KEY(1)];

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

    NSMutableDictionary *currencyUnits = [[self checkpointChanges] mutableCopy];

    NSNumber *lowest = [[currencyUnits allValues] valueForKeyPath:@"@min.self"];

    if (lowest != nil) {
        NSString *lowestKey = [currencyUnits allKeysForObject:lowest][0];
        [self autoBuyAll:lowestKey];
    }
}

@end
