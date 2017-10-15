//
//  Calculator+Trading.h
//  Calculator
//
//  Created by Markus Bröker on 15.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import "Calculator.h"

@interface Calculator (Trading)

/**
 * Buy the amount of assets to the latest price
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @return NSString*
 */
- (NSString *)autoBuy:(NSString *)cAsset amount:(double)wantedAmount;

/**
 * Buy the amount of assets to a specific rate
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @param wantedRate double
 * @return NSString*
 */
- (NSString *)autoBuy:(NSString *)cAsset amount:(double)wantedAmount withRate:(double)wantedRate;

/**
 * Sell the amount of assets to the latest price
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @return NSString*
 */
- (NSString *)autoSell:(NSString *)cAsset amount:(double)wantedAmount;

/**
 * Sell the amount of assets to a given rate
 *
 * @param cAsset NSString*
 * @param wantedAmount double
 * @param wantedRate double
 * @return NSString*
 */
- (NSString *)autoSell:(NSString *)cAsset amount:(double)wantedAmount withRate:(double)wantedRate;

/**
 * Buy all to the lastest price
 *
 * @param cAsset NSString*
 */
- (void)autoBuyAll:(NSString *)cAsset;

/**
 * Sell all to the lastest price
 *
 * @param cAsset NSString*
 */
- (void)autoSellAll:(NSString *)cAsset;

/**
 * Sell Altcoins with a gain of "wantedEuros"
 *
 * @param wantedEuros double
 */
- (void)sellWithProfitInEuro:(double)wantedEuros;

/**
 * Sell Altcoins with an investment Rate of wantedPercent or more
 *
 * @param wantedPercent double
 */
- (void)sellByInvestors:(double)wantedPercent;

/**
 * Buy Altcoins with an exchange rate of wantedPercent and an investment rate below wantedRate
 *
 * @param wantedPercent double
 * @param wantedRate double
 */
- (void)buyWithProfitInPercent:(double)wantedPercent andInvestmentRate:(double)wantedRate;

/**
 * Buy Altcoins with an investment Rate of wantedPercent or more
 *
 * @param wantedRate double
 */
- (void)buyByInvestors:(double)wantedRate;

/**
 * Buy the best Altcoin with the highest investment Rate
 *
 */
- (void)buyTheBest;

/**
 * Buy the best Altcoin with the lowest investment Rate
 *
 */
- (void)buyTheWorst;

@end