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

#import <objc/runtime.h>

#import "FBAuthenticationTests.h"
#import "FBError.h"
#import "FBSession.h"
#import "FBUtility.h"

@interface FBSystemAccountAuthenticationTests : FBAuthenticationTests
@end

@implementation FBSystemAccountAuthenticationTests
{
    Method _originalIsRegisteredCheck;
    Method _swizzledIsRegisteredCheck;
}

+ (BOOL)isRegisteredURLSchemeReplacement:(NSString *)url
{
    return YES;
}

- (void)setUp {
    [super setUp];
    _originalIsRegisteredCheck = class_getClassMethod([FBUtility class], @selector(isRegisteredURLScheme:));
    _swizzledIsRegisteredCheck = class_getClassMethod([self class], @selector(isRegisteredURLSchemeReplacement:));
    method_exchangeImplementations(_originalIsRegisteredCheck, _swizzledIsRegisteredCheck);
}

- (void)tearDown {
    [super tearDown];
    method_exchangeImplementations(_swizzledIsRegisteredCheck, _originalIsRegisteredCheck);
    _originalIsRegisteredCheck = nil;
    _swizzledIsRegisteredCheck = nil;
}

- (void)testOpenTriesSystemAccountAuthFirstIfAvailable {
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];
    
    [self mockSession:mockSession supportSystemAccount:YES];
    [self mockSession:mockSession expectSystemAccountAuth:YES succeed:NO];
    [self mockSession:mockSession supportMultitasking:NO];
    [self mockSession:mockSession expectFacebookAppAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:NO succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
           fromViewController:nil
            completionHandler:nil];
    
    [(id)mockSession verify];
    
    [session release];
}

- (void)testOpenDoesNotTrySystemAccountAuthIfUnavailableOnDevice {
    [self testOpenDoesNotTrySystemAccountAuthIfUnavailableServer:YES device:NO];
}

- (void)testOpenDoesNotTrySystemAccountAuthIfUnavailableOnServer {
    [self testOpenDoesNotTrySystemAccountAuthIfUnavailableServer:NO device:YES];
}

- (void)testOpenDoesNotTrySystemAccountAuthIfUnavailableServer:(BOOL)serverSupports
                                                        device:(BOOL)deviceSupports {
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];

    [self setFetchedSupportSystemAccount:serverSupports];
    [self mockSession:mockSession supportSystemAccount:deviceSupports];
    [self mockSession:mockSession expectSystemAccountAuth:NO succeed:NO];
    [self mockSession:mockSession supportMultitasking:NO];
    [self mockSession:mockSession expectFacebookAppAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:NO succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    __block NSError *handlerError = nil;
    [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
           fromViewController:nil
            completionHandler:^(FBSession *innerSession, FBSessionState status, NSError *error) {
                handlerError = [error retain];
            }];
    
    [(id)mockSession verify];

    XCTAssertNotNil(handlerError);
    XCTAssertTrue([FBErrorLoginFailedReasonInlineNotCancelledValue isEqualToString:handlerError.userInfo[FBErrorLoginFailedReason]]);

    [handlerError release];
    [session release];
}

- (void)testOpenDoesNotTrySystemAccountAuthWithForcingWebView {
    [self testImplOpenDoesNotTrySystemAccountAuthWithBehavior:FBSessionLoginBehaviorForcingWebView
                                            expectLoginDialog:YES];
}

- (void)testOpenDoesNotTrySystemAccountAuthWithWithFallbackToWebView {
    [self testImplOpenDoesNotTrySystemAccountAuthWithBehavior:FBSessionLoginBehaviorWithFallbackToWebView
                                            expectLoginDialog:YES];
}

- (void)testOpenDoesNotTrySystemAccountAuthWithNoFallbackToWebView {
    [self testImplOpenDoesNotTrySystemAccountAuthWithBehavior:FBSessionLoginBehaviorWithNoFallbackToWebView
                                            expectLoginDialog:NO];
}

- (void)testImplOpenDoesNotTrySystemAccountAuthWithBehavior:(FBSessionLoginBehavior)behavior
                                          expectLoginDialog:(BOOL)expectLoginDialog
{
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];
    
    [self mockSession:mockSession supportSystemAccount:YES];
    [self mockSession:mockSession expectSystemAccountAuth:NO succeed:NO];
    [self mockSession:mockSession supportMultitasking:NO];
    [self mockSession:mockSession expectFacebookAppAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:expectLoginDialog succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    [session openWithBehavior:behavior
           fromViewController:nil
            completionHandler:nil];
    
    [(id)mockSession verify];
    
    [session release];
}

- (void)testSystemAccountSuccess {
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];
    
    [self mockSession:mockSession supportSystemAccount:YES];
    [self mockSession:mockSession expectSystemAccountAuth:YES succeed:YES];
    [self mockSession:mockSession supportMultitasking:NO];
    [self mockSession:mockSession expectFacebookAppAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:NO succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    __block NSError *handlerError = nil;
    [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
           fromViewController:nil
            completionHandler:^(FBSession *innerSession, FBSessionState status, NSError *error) {
                handlerError = [error retain];
            }];
    
    [(id)mockSession verify];

    XCTAssertNil(handlerError);
    XCTAssertEqual(FBSessionStateOpen, session.state);
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertTrue([kAuthenticationTestValidToken isEqualToString:session.accessToken]);
    
    [handlerError release];
    [session release];
}

- (void)testSystemAccountFailureGeneratesError {
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];
    
    [self mockSession:mockSession supportSystemAccount:YES];
    [self mockSession:mockSession expectSystemAccountAuth:YES succeed:NO];
    [self mockSession:mockSession supportMultitasking:NO];
    [self mockSession:mockSession expectFacebookAppAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:NO succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    __block NSError *handlerError = nil;
    [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
            completionHandler:^(FBSession *innerSession, FBSessionState status, NSError *error) {
                handlerError = [error retain];
            }];
    
    [(id)mockSession verify];
    

    XCTAssertNotNil(handlerError);
    XCTAssertTrue([handlerError.userInfo[FBErrorLoginFailedReason] isEqualToString:FBErrorLoginFailedReasonSystemError]);
    XCTAssertEqual(FBSessionStateClosedLoginFailed, session.state);
    
    [handlerError release];
    [session release];
}

// TODO test untosed device continues auth process
// TODO test reauth case

- (void)testSystemAccountNotAvailableOnServerTriesNextAuthMethod {
    [self testSystemAccountNotAvailableTriesNextAuthMethodServer:NO device:YES];
}

- (void)testSystemAccountNotAvailableOnDeviceTriesNextAuthMethod {
    [self testSystemAccountNotAvailableTriesNextAuthMethodServer:YES device:NO];
}

- (void)testSystemAccountNotAvailableTriesNextAuthMethodServer:(BOOL)serverSupports
                                                        device:(BOOL)deviceSupports {
    FBSession *mockSession = [OCMockObject partialMockForObject:[FBSession alloc]];
    
    [self setFetchedSupportSystemAccount:serverSupports];
    [self mockSession:mockSession supportSystemAccount:deviceSupports];
    [self mockSession:mockSession expectSystemAccountAuth:NO succeed:NO];
    [self mockSession:mockSession supportMultitasking:YES];
    [self mockSession:mockSession expectFacebookAppAuth:YES try:YES results:nil];
    [self mockSession:mockSession expectSafariAuth:NO try:NO results:nil];
    [self mockSession:mockSession expectLoginDialogAuth:NO succeed:NO];
    
    FBSession *session = [mockSession initWithAppID:kAuthenticationTestAppId
                                        permissions:nil
                                    defaultAudience:FBSessionDefaultAudienceNone
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:nil];
    
    [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent completionHandler:nil];
    
    [(id)mockSession verify];
    
    [session release];
}


@end
