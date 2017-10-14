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

    calculator = [Calculator instance];
}

- (void)tearDown {
    [super tearDown];

    [Calculator reset];
}

/**
 * Check the computation
 */
- (void)testBTCPrice {
    for (int i = 1; i <= 10; i++) {
        double btcPrice = [calculator btcPriceForAsset:ASSET_KEY(i)];
        NSLog(@"1 %@ = %.8f %@", ASSET_KEY(i), btcPrice, ASSET_KEY(1));
    }
}

/**
 * Check the computation
 */
- (void)testFiatPrice {
    for (int i = 1; i <= 10; i++) {
        double euroPrice = [calculator fiatPriceForAsset:ASSET_KEY(i)];
        NSLog(@"1 %@ = %.8f EUR", ASSET_KEY(i), euroPrice);
    }
}

/**
 * Check the computation
 */
- (void)testBTC2Fiat {
    double euroPrice = [calculator btc2Fiat:1];
    NSLog(@"1 %@ = %.8f EUR", ASSET_KEY(1), euroPrice);
}

/**
 * Check the computation
 */
- (void)testFiat2BTC {
    double fiatPrice = [calculator fiat2BTC:5000];
    NSLog(@"5000 EUR = %.8f %@", fiatPrice, ASSET_KEY(1));
}

/**
 * Check the computation
 */
- (void)testCalculate {
    NSDictionary *dict = @{
        ASSET_KEY(1): @(1),
        ASSET_KEY(2): @(0),
        ASSET_KEY(3): @(0),
        ASSET_KEY(4): @(0),
        ASSET_KEY(5): @(0),
        ASSET_KEY(6): @(0),
        ASSET_KEY(7): @(0),
        ASSET_KEY(8): @(0),
        ASSET_KEY(9): @(0),
        ASSET_KEY(10): @(0),
    };

    [calculator updateBalances:dict];

    for (int i = 1; i <= 10; i++) {
        double sum = [calculator calculate:ASSET_KEY(i)];
        double factor = [calculator factorForAsset:ASSET_KEY(i) inRelationTo:ASSET_KEY(1)];

        NSLog(@"S: %.8f == %.8f", sum, factor);
        XCTAssertEqual(sum, factor, @"S: %.8f <> %.8f", sum, factor);
    }

}

@end
