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
    [self updateCheckpointForAsset:asset withBTCUpdate:btcUpdate andRate:0.0];
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

    if (self.currentRatings == nil) {
        NSLog(@"updateCheckPointForAsset: NO DATA");

        return;
    }

    if ([asset isEqualToString:DASHBOARD]) {
        self.initialRatings = [self.currentRatings mutableCopy];
    } else {
        // aktualisiere den Kurs der Währung
        self.initialRatings[asset] = ((wantedRate == 0.0) ? self.currentRatings[asset] : @(wantedRate));

        if (![asset isEqualToString:self.masterKey] && btcUpdate) {
            // aktualisiere den BTC Kurs, auf den sich die Transaktion bezog
            self.initialRatings[self.masterKey] = self.currentRatings[self.masterKey];
        }
    }

    [defaults setObject:self.initialRatings forKey:KEY_INITIAL_RATINGS];
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

    double initialAssetRating = [self.initialRatings[asset] doubleValue];
    double currentAssetRating = [self.currentRatings[asset] doubleValue];

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

    for (id cAsset in self.currentRatings) {
        NSDictionary *aCheckpoint = [self checkpointForAsset:cAsset];
        double cPercent = [aCheckpoint[CP_PERCENT] doubleValue];

        checkpointChanges[cAsset] = @(cPercent);
    }

    return checkpointChanges;
}

@end
