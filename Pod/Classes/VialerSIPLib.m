//
//  VialerSIPLib.m
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import "VialerSIPLib.h"

#import <CocoaLumberjack/CocoaLumberjack.h>
#import "NSError+VSLError.h"
#import "VSLAccount.h"
#import "VSLAccountConfiguration.h"
#import "VSLCall.h"
#import "VSLEndpoint.h"

static NSString * const VialerSIPLibErrorDomain = @"VialerSIPLib.error";

@interface VialerSIPLib()
@property (strong, nonatomic) VSLEndpoint *endpoint;
@end

@implementation VialerSIPLib

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;

    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (VSLEndpoint *)endpoint {
    if (!_endpoint) {
        _endpoint = [VSLEndpoint sharedEndpoint];
    }
    return _endpoint;
}

- (BOOL)endpointAvailable {
    if (self.endpoint.state == VSLEndpointStarted) {
        return YES;
    }
    return NO;
}

- (BOOL)configureLibraryWithEndPointConfiguration:(VSLEndpointConfiguration * _Nonnull)endpointConfiguration error:(NSError * _Nullable __autoreleasing *)error {
    // Make sure interrupts are handled by pjsip
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    // Start the Endpoint
    NSError *endpointConfigurationError;
    BOOL success = [self.endpoint startEndpointWithEndpointConfiguration:endpointConfiguration error:&endpointConfigurationError];
    if (endpointConfigurationError && error != NULL) {
        *error = [NSError VSLUnderlyingError:endpointConfigurationError
           localizedDescriptionKey:NSLocalizedString(@"The endpoint configuration has failed.", nil)
       localizedFailureReasonError:nil
                       errorDomain:VialerSIPLibErrorDomain
                         errorCode:VialerSIPLibErrorEndpointConfigurationFailed];
    }
    return success;
}

- (void)removeEndpoint {
    [self.endpoint destoryPJSUAInstance];
}

- (VSLAccount *)createAccountWithSipUser:(id<SIPEnabledUser>  _Nonnull __autoreleasing)sipUser error:(NSError * _Nullable __autoreleasing *)error {
    VSLAccountConfiguration *accountConfiguration = [[VSLAccountConfiguration alloc] init];
    accountConfiguration.sipAccount = sipUser.sipAccount;
    accountConfiguration.sipPassword = sipUser.sipPassword;
    accountConfiguration.sipDomain = sipUser.sipDomain;
    accountConfiguration.sipProxyServer = sipUser.sipProxy ? sipUser.sipProxy : @"";
    accountConfiguration.sipRegisterOnAdd = sipUser.sipRegisterOnAdd;

    VSLAccount *account = [[VSLAccount alloc] init];

    NSError *accountConfigError = nil;
    [account configureWithAccountConfiguration:accountConfiguration error:&accountConfigError];
    if (accountConfigError && error != NULL) {
        *error = accountConfigError;
        return nil;
    }
    return account;
}

- (void)setIncomingCallBlock:(void (^)(VSLCall * _Nonnull))incomingCallBlock {
    [VSLEndpoint sharedEndpoint].incomingCallBlock = incomingCallBlock;
}

- (BOOL)registerAccount:(id<SIPEnabledUser> _Nonnull __autoreleasing)sipUser error:(NSError * _Nullable __autoreleasing *)error {
    VSLAccount *account = [self.endpoint getAccountWithSipAccount:sipUser.sipAccount];

    if (!account) {
        NSError *accountConfigError;
        account = [self createAccountWithSipUser:sipUser error:&accountConfigError];
        if (!account) {
            if (error != nil) {
                *error = [NSError VSLUnderlyingError:accountConfigError
                   localizedDescriptionKey:NSLocalizedString(@"The configure the account has failed.", nil)
               localizedFailureReasonError:nil
                               errorDomain:VialerSIPLibErrorDomain
                                 errorCode:VialerSIPLibErrorAccountConfigurationFailed];

            }
            return NO;
        }
    }

    if (account.accountState == VSLAccountStateOffline || account.accountState == VSLAccountStateDisconnected) {
        NSError *accountError;
        BOOL success = [account registerAccount:&accountError];
        if (!success) {
            if (error != nil) {
                *error = [NSError VSLUnderlyingError:accountError
                             localizedDescriptionKey:NSLocalizedString(@"The registration of the account has failed.", nil)
                         localizedFailureReasonError:nil
                                         errorDomain:VialerSIPLibErrorDomain
                                           errorCode:VialerSIPLibErrorAccountRegistrationFailed];
            }
            return NO;
        }
    }
    return YES;
}

- (VSLCall *)getVSLCallWithId:(NSString *)callId andSipUser:(id<SIPEnabledUser>  _Nonnull __autoreleasing)sipUser {
    if (!callId) {
        return nil;
    }

    VSLAccount *account = [self.endpoint getAccountWithSipAccount:sipUser.sipAccount];

    if (!account) {
        return nil;
    }

    VSLCall *call = [account lookupCall:[callId intValue]];

    return call;
}

- (VSLAccount *)firstAccount {
    return [self.endpoint.accounts firstObject];
}

- (BOOL)anotherCallInProgress:(VSLCall *)call {
    VSLAccount *account = [self firstAccount];
    VSLCall *activeCall = [account firstActiveCall];

    if (call.callId != activeCall.callId) {
        return YES;
    }
    return NO;
}

@end
