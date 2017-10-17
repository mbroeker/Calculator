//
//  CalculatorTests.m
//  CalculatorTests
//
//  Created by Markus Bröker on 11.10.17.
//  Copyright © 2017 Markus Bröker. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Calculator/Calculator.h>

@interface CalculatorTests : XCTestCase

@end

@implementation CalculatorTests {
    Calculator *calculator;
}

- (void)setUp {
    [super setUp];

    calculator = [Calculator instance:@[EUR, USD]];
}

- (void)tearDown {
    [super tearDown];

    [Calculator reset];
}

/**
 * Check the computation
 */
- (void)testBTCPrice {
    for (id key in [calculator currentRatings]) {
        NSString *asset = [key componentsSeparatedByString:@"_"][1];
        double btcPrice = [calculator btcPriceForAsset:key];
        NSLog(@"1 %@ = %.8f %@", asset, btcPrice, ASSET_KEY);
    }
}

/**
 * Check the computation
 */
- (void)testFiatPrice {
    for (id key in [calculator currentRatings]) {
        double fiatPrice = [calculator fiatPriceForAsset:key];
        NSLog(@"1 %@ = %.8f %@", key, fiatPrice, [calculator fiatCurrencies][0]);
    }
}

/**
 * Check the computation
 */
- (void)testBTC2Fiat {
    double fiatPrice = [calculator btc2Fiat:1];
    NSLog(@"1 %@ = %.8f %@", ASSET_KEY, fiatPrice, [calculator fiatCurrencies][0]);
}

/**
 * Check the computation
 */
- (void)testFiat2BTC {
    double fiatPrice = [calculator fiat2BTC:5000];
    NSLog(@"5000 %@ = %.8f %@", [calculator fiatCurrencies][0], fiatPrice, ASSET_KEY);
}

- (void)testCalculate {
    for (id key in [calculator currentRatings]) {
        double sum = [calculator calculate:key];
        NSLog(@"Sum: %@ => %.8f", key, sum);

        if (isinf(sum)) { break; }
    }
}

@end
