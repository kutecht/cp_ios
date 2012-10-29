//
//  CPUserDefaultsHandler.m
//  candpiosapp
//
//  Created by Stephen Birarda on 7/3/12.
//  Copyright (c) 2012 Coffee and Power Inc. All rights reserved.
//

#import "CPUserDefaultsHandler.h"
#import "ContactListViewController.h"
#import "CPTabBarController.h"

// define a way to quickly grab and set NSUserDefaults
#define DEFAULTS(type, key) ([[NSUserDefaults standardUserDefaults] type##ForKey:key])
#define SET_DEFAULTS(Type, key, val) do {\
[[NSUserDefaults standardUserDefaults] set##Type:val forKey:key];\
[[NSUserDefaults standardUserDefaults] synchronize];\
} while (0)


@implementation CPUserDefaultsHandler

NSString* const kUDCurrentUser = @"loggedUser";

+ (void)setCurrentUser:(User *)currentUser
{
#if DEBUG
    NSLog(@"Storing user data for user with ID %d and nickname %@ to NSUserDefaults", currentUser.userID, currentUser.nickname);
#endif

    [[CPAppDelegate appCache] removeObjectForKey:kUDCurrentUser];
    // encode the user object
    NSData *encodedUser = [NSKeyedArchiver archivedDataWithRootObject:currentUser];
    
    // store it in user defaults
    SET_DEFAULTS(Object, kUDCurrentUser, encodedUser);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LoginStateChanged" object:nil];
}

+ (User *)currentUser
{
    if (DEFAULTS(object, kUDCurrentUser)) {
        User *user = [[CPAppDelegate appCache] objectForKey:kUDCurrentUser];

        if (!user) {
            // grab the coded user from NSUserDefaults
            NSData *myEncodedObject = DEFAULTS(object, kUDCurrentUser);
            user = (User *)[NSKeyedUnarchiver unarchiveObjectWithData:myEncodedObject];
            if (!user) {
                return nil;
            }
            [[CPAppDelegate appCache] setObject:user forKey:kUDCurrentUser];
        }
        // return it
        return user;
    } else {
        return nil;
    }
}

NSString* const kUDNumberOfContactRequests = @"numberOfContactRequests";
+ (void)setNumberOfContactRequests:(NSInteger)numberOfContactRequests
{
    SET_DEFAULTS(Integer, kUDNumberOfContactRequests, numberOfContactRequests);
    
    // update the badge on the contacts tab number
    CPThinTabBar *thinTabBar = (CPThinTabBar *)[[CPAppDelegate  tabBarController] tabBar];
    [thinTabBar setBadgeNumber:[NSNumber numberWithInteger:numberOfContactRequests]
                    atTabIndex:(kNumberOfTabsRightOfButton - 1)];
}

+ (NSInteger)numberOfContactRequests
{
    return DEFAULTS(integer, kUDNumberOfContactRequests);
}

NSString* const kUDCurrentVenue = @"currentCheckIn";

+ (void)setCurrentVenue:(CPVenue *)venue
{
    // encode the venue object
    NSData *newVenueData = [NSKeyedArchiver archivedDataWithRootObject:venue];
    
    // store it in user defaults
    SET_DEFAULTS(Object, kUDCurrentVenue, newVenueData);
}

+ (CPVenue *)currentVenue
{
    if (DEFAULTS(object, kUDCurrentVenue)) {
        // grab the coded user from NSUserDefaults
        NSData *myEncodedObject = DEFAULTS(object, kUDCurrentVenue);
        // return it
        return (CPVenue *)[NSKeyedUnarchiver unarchiveObjectWithData:myEncodedObject];
    } else {
        return nil;
    }
}


NSString* const kUDPastVenues = @"pastVenues";
+ (void)setPastVenues:(NSArray *)pastVenues
{
    SET_DEFAULTS(Object, kUDPastVenues, pastVenues);  
}

+ (NSArray *)pastVenues
{
    return DEFAULTS(object, kUDPastVenues);
}

#define kCheckoutMonitorDuration 20.0
#define kWarnBeforeCheckoutInMin  5.0
#define kSecondsPerMinute          60

NSString* const kUDCheckoutTime = @"localUserCheckoutTime";
NSString* const kUDCheckoutTimeWarned = @"localUserCheckoutTimeWarned";
NSString* const kUDCheckoutTimeReached = @"localUserCheckoutTimeReached";

+ (void)monitorCheckoutTime
{
    BOOL hasCheckoutBeenReached = [DEFAULTS(object, kUDCheckoutTimeReached) boolValue];
    if ([CPUserDefaultsHandler isUserCurrentlyCheckedIn])
    {
#if DEBUG
        NSLog(@"%g minutes till checkout", ([CPUserDefaultsHandler checkoutTime] - [[NSDate date]timeIntervalSince1970])/kSecondsPerMinute);
#endif
        
        // Display warning
        BOOL hasBeenWarned = [DEFAULTS(object, kUDCheckoutTimeWarned) boolValue];
        if ((!hasBeenWarned) && ((([CPUserDefaultsHandler checkoutTime] - [[NSDate date]timeIntervalSince1970])/kSecondsPerMinute) < kWarnBeforeCheckoutInMin))  {
            
            //
            // warn user about checkout happening soon
            //
#if DEBUG            
            NSLog(@"Sending warning that checkout to happen soon.");
#endif
            
            UILocalNotification *localNotif = [[UILocalNotification alloc] init];
            
            CPVenue *venue = [self currentVenue];
            int minutesLeft = (int)(([CPUserDefaultsHandler checkoutTime] - [[NSDate date]timeIntervalSince1970])/60);
            if (venue) {
                localNotif.alertBody = [NSString stringWithFormat:@"You will be checked out of %@ in %d minutes.",
                                        venue.name, minutesLeft];
            }
            else {
                localNotif.alertBody = [NSString stringWithFormat:@"You will be checked out in %d minutes.", minutesLeft];
            }
            localNotif.alertAction = @"Check Out";
            localNotif.soundName = UILocalNotificationDefaultSoundName;
            
            // since it is undetermined which thread calls monitorCheckoutTime, for safety doing the notify on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
            });
            
            SET_DEFAULTS(Object, kUDCheckoutTimeWarned, [NSNumber numberWithBool:YES]);
        }
        
        
        
        [self performSelector:@selector(monitorCheckoutTime) withObject:nil afterDelay:kCheckoutMonitorDuration];
    }
    else if (!hasCheckoutBeenReached) {
        
        //
        // send notification for action menu to update image for the checkin button
        //
        
#if DEBUG
        NSLog(@"Sending notifiection that checkin state changed.");
#endif

        // since it is undetermined which thread calls monitorCheckoutTime, for safety doing the notify on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"userCheckInStateChange" object:nil];
        });
        
        SET_DEFAULTS(Object, kUDCheckoutTimeReached, [NSNumber numberWithBool:YES]);
    }
}

+ (void)setCheckoutTime:(NSInteger)checkoutTime
{
    NSInteger storedCheckoutTime = [self checkoutTime];
    
    if (checkoutTime != storedCheckoutTime)
    {
        // checkoutTime has changed, reset warning flag
        
        // set the NSUserDefault to the user checkout time
        SET_DEFAULTS(Object, kUDCheckoutTime, [NSNumber numberWithInt:checkoutTime]);
        SET_DEFAULTS(Object, kUDCheckoutTimeWarned, [NSNumber numberWithBool:NO]);
    }
    
    if (checkoutTime > [[NSDate date]timeIntervalSince1970])
    {
        SET_DEFAULTS(Object, kUDCheckoutTimeReached, [NSNumber numberWithBool:NO]);
    }
    else
    {
        SET_DEFAULTS(Object, kUDCheckoutTimeReached, [NSNumber numberWithBool:YES]);
    }
    
    // always start montioring even if chechoutTime unchanged -- needed when app restarts before user checked out.
    [self cancelPreviousPerformRequestsWithTarget:self selector:@selector(monitorCheckoutTime) object:nil];
    [self performSelector:@selector(monitorCheckoutTime) withObject:nil afterDelay:kCheckoutMonitorDuration];
}

+ (NSInteger)checkoutTime
{
    return [DEFAULTS(object, kUDCheckoutTime) intValue];
}

+ (BOOL)isUserCurrentlyCheckedIn
{
    return [self checkoutTime] > [[NSDate date]timeIntervalSince1970];
}


NSString* const kUDLastLoggedAppVersion = @"lastLoggedAppVersion";
+ (void)setLastLoggedAppVersion:(NSString *)appVersionString
{
    SET_DEFAULTS(Object, kUDLastLoggedAppVersion, appVersionString);
}

+ (NSString *)lastLoggedAppVersion
{
    return DEFAULTS(object, kUDLastLoggedAppVersion);
}

NSString* const kAutomaticCheckins = @"automaticCheckins";

+ (void)setAutomaticCheckins:(BOOL)on
{
    SET_DEFAULTS(Object, kAutomaticCheckins, [NSNumber numberWithBool:on]);
}

+ (BOOL)automaticCheckins
{
    return [DEFAULTS(object, kAutomaticCheckins) boolValue];
}

@end
