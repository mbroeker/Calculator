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
    double btcPrice = [calculator btcPriceForAsset:ASSET_KEY(3)];
    double euroPrice = [calculator fiatPriceForAsset:ASSET_KEY(3)];

    NSLog(@"%@ Price for %@ = %.8f BTC / %.4f €", ASSET_KEY(1), ASSET_DESC(3), btcPrice, euroPrice);
}

/**
 * Check the computation
 */
- (void)testCalculate {
    NSDictionary *dict = @{
        ASSET_KEY(1): @(0.5),
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
        double factor = [calculator factorForAsset:ASSET_KEY(i) inRelationTo:ASSET_KEY(3)];
        NSLog(@"SUM %@ => %.4f : %.8f", ASSET_KEY(i), sum, factor);
    }

}

@end
