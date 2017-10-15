//
//  Calculator+Checkpoints.h
//  Calculator
//
//  Created by Markus Bröker on 15.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator.h"

@interface Calculator (Checkpoints)

/**
 * Update the current checkpoint for the given asset and optionally update the btc checkpoint
 *
 * @param asset NSString*
 * @param btcUpdate BOOL
 */
- (void)updateCheckpointForAsset:(NSString *)asset withBTCUpdate:(BOOL)btcUpdate;

/**
 * Update the current checkpoint for the given asset and optionally update the btc checkpoint with a given rate
 *
 * @param asset NSString*
 * @param btcUpdate BOOL
 * @param rate double
 */
- (void)updateCheckpointForAsset:(NSString *)asset withBTCUpdate:(BOOL)btcUpdate andRate:(double)wantedRate;

/**
 * Returns a NSDictionary with keys "initialPrice", "currentPrice", "percent"
 *
 * @param asset NSString*
 * @return NSDictionary*
 */
- (NSDictionary *)checkpointForAsset:(NSString *)asset;

/**
 * Returns the current checkpoint changes
 *
 * @return NSDictionary*
 */
- (NSDictionary *)checkpointChanges;

@end
