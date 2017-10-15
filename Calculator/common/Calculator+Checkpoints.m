//
//  Calculator+Checkpoints.m
//  Calculator
//
//  Created by Markus Bröker on 15.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator+Checkpoints.h"

@implementation Calculator (Checkpoints)

/**
 * Aktualisiere die Kurse der jeweiligen Währung
 *
 * @param asset NSString*
 * @param btcUpdate BOOL
 */
- (void)updateCheckpointForAsset:(NSString *)asset withBTCUpdate:(BOOL)btcUpdate {
    return [self updateCheckpointForAsset:asset withBTCUpdate:btcUpdate andRate:0.0];
}

/**
 * Aktualisiere die Kurse der jeweiligen Währung
 *
 * @param asset NSString*
 * @param btcUpdate BOOL
 * @param rate double
 */
- (void)updateCheckpointForAsset:(NSString *)asset withBTCUpdate:(BOOL)btcUpdate andRate:(double)wantedRate {
    NSDebug(@"Calculator::updateCheckpointForAsset:%@ withBTCUpdate:%d andRate:%.8f", asset, btcUpdate, wantedRate);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSMutableDictionary *currentRatings = [self currentRatings];
    NSMutableDictionary *initialRatings = [self initialRatings];

    if (currentRatings == nil || initialRatings == nil) {
        NSLog(@"updateCheckPointForAsset: NO DATA");

        return;
    }

    if ([asset isEqualToString:DASHBOARD]) {
        initialRatings = [currentRatings mutableCopy];
    } else {
        // aktualisiere den Kurs der Währung
        initialRatings[asset] = ((wantedRate == 0.0) ? currentRatings[asset] : @(wantedRate));

        if (![asset isEqualToString:ASSET_KEY(1)] && btcUpdate) {
            // aktualisiere den BTC Kurs, auf den sich die Transaktion bezog
            initialRatings[ASSET_KEY(1)] = currentRatings[ASSET_KEY(1)];
        }
    }

    [defaults setObject:initialRatings forKey:KEY_INITIAL_RATINGS];
    [defaults synchronize];
}

/**
 * Liefert NSDictionary mit den Schlüsseln "initialPrice", "currentPrice", "percent"
 *
 * @param asset NSString*
 * @return NSDictionary*
 */
- (NSDictionary *)checkpointForAsset:(NSString *)asset {
    //NSDebug(@"Calculator::checkpointForAsset:%@", asset);

    NSMutableDictionary *currentRatings = [self currentRatings];
    NSMutableDictionary *initialRatings = [self initialRatings];

    double initialAssetRating = [initialRatings[asset] doubleValue];
    double currentAssetRating = [currentRatings[asset] doubleValue];

    if (initialAssetRating == 0.0) {
        initialAssetRating = currentAssetRating;
        [self updateCheckpointForAsset:asset withBTCUpdate:false andRate:[self fiatPriceForAsset:asset]];
    }

    double initialPrice = initialAssetRating;
    double currentPrice = currentAssetRating;

    double percent = 100.0 * ((currentPrice / initialPrice) - 1);

    return @{
        CP_INITIAL_PRICE: @(initialPrice),
        CP_CURRENT_PRICE: @(currentPrice),
        CP_PERCENT: @(percent)
    };
}

/**
 * Liefert die aktuellen Veränderungen in Prozent
 *
 * @return NSDictionary*
 */
- (NSDictionary *)checkpointChanges {
    NSDebug(@"Calculator::checkpointChanges");

    NSMutableDictionary *checkpointChanges = [[NSMutableDictionary alloc] init];

    NSMutableDictionary *currentRatings = [self currentRatings];

    for (id cAsset in currentRatings) {
        if ([cAsset isEqualToString:USD]) { continue; }

        NSDictionary *aCheckpoint = [self checkpointForAsset:cAsset];
        double cPercent = [aCheckpoint[CP_PERCENT] doubleValue];

        checkpointChanges[cAsset] = @(cPercent);
    }

    return checkpointChanges;
}

@end
