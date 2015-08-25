/*
 * Copyright 2010-present Facebook.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FBGraphLocation.h"
#import "FBGraphObject.h"
#import "FBGraphPlace.h"
#import "FBGraphUser.h"
#import "FBRequest.h"
#import "FBRequestConnection.h"
#import "FBTestBlocker.h"
#import "FBTests.h"

@protocol TestGraphProtocolTooManyArgs<FBGraphObject>
- (int)thisMethod:(int)has too:(int)many args:(int)yikes;
@end

@protocol TestGraphProtocolOptionalMethod<FBGraphObject>
@optional
- (NSString *)name;
@end

@protocol TestGraphProtocolVeryFewMethods<FBGraphObject>
@end

@protocol T1<FBGraphObject>
- (NSString *)name;
@end

@protocol T2
@end

@protocol TestGraphProtocolBoooBadLineage
- (NSString *)name;
@end

@protocol TestGraphProtocolBoooBadLineage2<TestGraphProtocolTooManyArgs>
- (NSString *)title;
@end

@protocol TestGraphProtocolGoodLineage3<T1, T2>
- (NSString *)title;
@end

@protocol TestGraphProtocolGoodLineage<TestGraphProtocolVeryFewMethods>
- (NSString *)title;
@end

@protocol TestGraphProtocolGoodLineage2<TestGraphProtocolVeryFewMethods, T1>
- (NSString *)title;
@end

@protocol NamedGraphObject<FBGraphObject>
@property (nonatomic, retain) NSString *name;
@end

@protocol NamedGraphObjectWithExtras<NamedGraphObject>
- (void)methodWithAnArg:(id)arg1 andAnotherArg:(id)arg2;
@end

@interface FBGraphObject (FBGraphObjectTests)
+ (instancetype)graphObjectWrappingObject:(id)originalObject;
@end

@interface FBGraphObjectTests : FBTests
@end

@implementation FBGraphObjectTests

- (void)testCreateEmptyGraphObject {
    id<FBGraphObject> graphObject = [FBGraphObject graphObject];
    XCTAssertNotNil(graphObject, @"could not create FBGraphObject");
}

- (void)testCanSetProperty {
    id<NamedGraphObject> graphObject = (id<NamedGraphObject>)[FBGraphObject graphObject];
    [graphObject setName:@"A name"];
    XCTAssertTrue([@"A name"  isEqualToString:graphObject.name]);
}

- (void)testRespondsToSelector {
    id<NamedGraphObject> graphObject = (id<NamedGraphObject>)[FBGraphObject graphObject];
    BOOL respondsToSelector = [graphObject respondsToSelector:@selector(setName:)];
    XCTAssertTrue(respondsToSelector);
}

- (void)testDoesNotHandleNonGetterSetter {
    @try {
        id<NamedGraphObjectWithExtras> graphObject = (id<NamedGraphObjectWithExtras>)[FBGraphObject graphObject];
        [graphObject methodWithAnArg:@"foo" andAnotherArg:@"bar"];
        XCTFail(@"should have gotten exception");
    } @catch (NSException *exception) {
    }
}

- (void)testCanRemoveObject {
    NSDictionary *initial = [[NSDictionary alloc] initWithObjectsAndKeys:
                             @"value", @"key",
                             nil];
    NSMutableDictionary<FBGraphObject> *graphObject = [FBGraphObject graphObjectWrappingDictionary:initial];

    XCTAssertNotNil([graphObject objectForKey:@"key"], @"should have 'key'");

    [graphObject removeObjectForKey:@"key"];

    XCTAssertNil([graphObject objectForKey:@"key"], @"should not have 'key'");
}

- (void)testWrapWithGraphObject
{
    // construct a dictionary with an array and object as values
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:[NSArray arrayWithObjects:@"one", [NSMutableDictionary dictionary], @"three", nil]
          forKey:@"array"];
    [d setObject:[NSMutableDictionary dictionary] forKey:@"object"];

    // make sure we got the object we expected when FBGraphObject-ifying it
    id obj = [FBGraphObject graphObjectWrappingDictionary:d];
    XCTAssertTrue([obj class] == [FBGraphObject class], @"Wrong class for resulting graph object");

    // make sure we don't double-wrap
    id obj2 = [FBGraphObject graphObjectWrappingDictionary:obj];
    XCTAssertTrue(obj == obj2, @"Different object implies faulty double-wrap");

    // use inferred implementation to fetch obj.array
    NSMutableArray *arr = [obj performSelector:@selector(array)];

    // did we get our array?
    XCTAssertTrue([arr isKindOfClass:[NSMutableArray class]], @"Wrong class for resulting graph object array");

    // make sure we don't double-wrap arrays
    obj2 = [FBGraphObject performSelector:@selector(graphObjectWrappingObject:) withObject:arr];
    XCTAssertTrue(arr == obj2, @"Different object implies faulty double-wrap");

    // is the first object the expected object?
    XCTAssertTrue([[arr objectAtIndex:0] isEqual:@"one"], @"Wrong array contents");

    // is the second index in the array wrapped?
    XCTAssertTrue([[arr objectAtIndex:1] class] == [FBGraphObject class], @"Wrong class for array element");

    // is the second object in the dictionary wrapped?
    XCTAssertTrue([[obj objectForKey:@"object"] class] == [FBGraphObject class], @"Wrong class for object item");

    // nil case?
    XCTAssertNil([FBGraphObject graphObjectWrappingDictionary:nil], @"Wrong result for nil wrapper");
}

- (void)testGraphObjectProtocolImplInference
{
    // get an object
    NSMutableDictionary *obj = [NSMutableDictionary dictionary];
    obj = [FBGraphObject graphObjectWrappingDictionary:obj];

    // assert its ability to be used with graph protocols (Note: new graph protocols should get a new line here
    XCTAssertTrue([obj conformsToProtocol:@protocol(FBGraphUser)], @"protocol inference is broken");
    XCTAssertTrue([obj conformsToProtocol:@protocol(FBGraphPlace)], @"protocol inference is broken");
    XCTAssertTrue([obj conformsToProtocol:@protocol(FBGraphLocation)], @"protocol inference is broken");

    // prove to ourselves we aren't always getting a yes
    XCTAssertFalse([obj conformsToProtocol:@protocol(TestGraphProtocolTooManyArgs)], @"protocol should not be inferrable");
    XCTAssertFalse([obj conformsToProtocol:@protocol(TestGraphProtocolOptionalMethod)], @"protocol should not be inferrable");
    XCTAssertFalse([obj conformsToProtocol:@protocol(TestGraphProtocolBoooBadLineage)], @"protocol should not be inferrable");
    XCTAssertFalse([obj conformsToProtocol:@protocol(TestGraphProtocolBoooBadLineage2)], @"protocol should not be inferrable");

    // some additional yes cases
    XCTAssertTrue([obj conformsToProtocol:@protocol(TestGraphProtocolGoodLineage)], @"protocol inference is broken");
    XCTAssertTrue([obj conformsToProtocol:@protocol(TestGraphProtocolGoodLineage2)], @"protocol inference is broken");
    XCTAssertTrue([obj conformsToProtocol:@protocol(TestGraphProtocolVeryFewMethods)], @"protocol should be inferrable");
    XCTAssertTrue([obj conformsToProtocol:@protocol(TestGraphProtocolGoodLineage3)], @"protocol should be inferrable");
}

- (void)testGraphObjectSameID
{
    NSString *anID = @"1234567890";

    id obj = [NSMutableDictionary dictionary];
    [obj setObject:anID forKey:@"id"];
    obj = [FBGraphObject graphObjectWrappingDictionary:obj];

    id objSameID = [NSMutableDictionary dictionary];
    [objSameID setObject:anID forKey:@"id"];
    objSameID = [FBGraphObject graphObjectWrappingDictionary:objSameID];

    id objDifferentID = [NSMutableDictionary dictionary];
    [objDifferentID setObject:@"999999" forKey:@"id"];
    objDifferentID = [FBGraphObject graphObjectWrappingDictionary:objDifferentID];

    id objNoID = [NSMutableDictionary dictionary];
    objNoID = [FBGraphObject graphObjectWrappingDictionary:objNoID];
    id objAnotherNoID = [NSMutableDictionary dictionary];
    objAnotherNoID = [FBGraphObject graphObjectWrappingDictionary:objAnotherNoID];

    XCTAssertTrue([FBGraphObject isGraphObjectID:obj sameAs:objSameID], @"same ID");
    XCTAssertTrue([FBGraphObject isGraphObjectID:obj sameAs:obj], @"same object");

    XCTAssertFalse([FBGraphObject isGraphObjectID:obj sameAs:objDifferentID], @"not same ID");

    // Objects with no ID should never match
    XCTAssertFalse([FBGraphObject isGraphObjectID:obj sameAs:objNoID], @"no ID");
    XCTAssertFalse([FBGraphObject isGraphObjectID:objNoID sameAs:obj], @"no ID");

    // Nil objects should never match an object with an ID
    XCTAssertFalse([FBGraphObject isGraphObjectID:obj sameAs:nil], @"nil object");
    XCTAssertFalse([FBGraphObject isGraphObjectID:nil sameAs:obj], @"nil object");

    // Having no ID is different than being a nil object
    XCTAssertFalse([FBGraphObject isGraphObjectID:objNoID sameAs:nil], @"nil object");

    // Two objects with no ID shouldn't match unless they are the same object.
    XCTAssertFalse([FBGraphObject isGraphObjectID:objNoID sameAs:objAnotherNoID], @"no IDs but different objects");
    XCTAssertTrue([FBGraphObject isGraphObjectID:objNoID sameAs:objNoID], @"no ID but same object");
}

- (id)graphObjectWithUnwrappedData
{
    NSDictionary *rawDictionary1 = [NSDictionary dictionaryWithObjectsAndKeys:@"world", @"hello", nil];
    NSDictionary *rawDictionary2 = [NSDictionary dictionaryWithObjectsAndKeys:@"world", @"bye", nil];
    NSArray *rawArray1 = [NSArray arrayWithObjects:@"anda1", @"anda2", @"anda3", nil];
    NSArray *rawArray2 = [NSArray arrayWithObjects:@"anda1", @"anda2", @"anda3", nil];

    NSDictionary *rawObject = [NSDictionary dictionaryWithObjectsAndKeys:
                               rawDictionary1, @"dict1",
                               rawDictionary2, @"dict2",
                               rawArray1, @"array1",
                               rawArray2, @"array2",
                               nil];
    NSDictionary<FBGraphObject> *graphObject = [FBGraphObject graphObjectWrappingDictionary:rawObject];

    return graphObject;
}

- (void)traverseGraphObject:(id)graphObject
{
    if ([graphObject isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in graphObject) {
            id value = [graphObject objectForKey:key];
            XCTAssertNotNil(value, @"missing value");
            [self traverseGraphObject:value];
        }
    } else if ([graphObject isKindOfClass:[NSArray class]]) {
        for (NSString *value in graphObject) {
            XCTAssertNotNil(value, @"missing value");
            [self traverseGraphObject:value];
        }
    }
}

- (void)testEnumeration
{
    id graphObject = [self graphObjectWithUnwrappedData];
    [self traverseGraphObject:graphObject];
}

- (void)testArrayObjectEnumerator
{
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];

    NSEnumerator *enumerator = [array objectEnumerator];
    id o;
    int count = 0;
    while (o = [enumerator nextObject]) {
        XCTAssertNotNil(o);
        count++;
    }
    XCTAssertEqual(3, count);
}

- (void)testArrayObjectReverseEnumerator
{
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];

    NSEnumerator *enumerator = [array reverseObjectEnumerator];
    id o;
    int count = 0;
    while (o = [enumerator nextObject]) {
        XCTAssertNotNil(o);
        count++;
    }
    XCTAssertEqual(3, count);
}

- (void)testInsertObjectAtIndex {
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];
    [array insertObject:@"two" atIndex:1];

    XCTAssertTrue([array[1] isEqualToString:@"two"]);

}

- (void)testRemoveObjectAtIndex {
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];
    [array removeObjectAtIndex:1];

    XCTAssertEqual(2, array.count);
}

- (void)testAddObject {
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];
    [array addObject:@"four"];

    XCTAssertTrue([array[3] isEqualToString:@"four"]);
}

- (void)testRemoveLastObject {
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];
    [array removeLastObject];

    XCTAssertEqual(2, array.count);
}

- (void)testReplaceObjectAtIndex {
    NSMutableDictionary<FBGraphObject> *obj = [self createGraphObjectWithArray];
    NSMutableArray *array = [obj objectForKey:@"array"];
    [array replaceObjectAtIndex:1 withObject:@"two"];

    XCTAssertTrue([array[1] isEqualToString:@"two"]);
}

- (NSMutableDictionary<FBGraphObject> *)createGraphObjectWithArray {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:[NSArray arrayWithObjects:@"one", [NSMutableDictionary dictionary], @"three", nil]
          forKey:@"array"];
    [d setObject:[NSMutableDictionary dictionary] forKey:@"object"];
    
    NSMutableDictionary<FBGraphObject> *obj = [FBGraphObject graphObjectWrappingDictionary:d];

    return obj;
}

@end
