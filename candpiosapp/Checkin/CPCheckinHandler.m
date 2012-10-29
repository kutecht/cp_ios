//
//  CPCheckinHandler.m
//  candpiosapp
//
//  Created by Stephen Birarda on 6/26/12.
//  Copyright (c) 2012 Coffee and Power Inc. All rights reserved.
//

#import "CPCheckinHandler.h"
#import "CPGeofenceHandler.h"
#import "CheckInDetailsViewController.h"
#import "ChangeHeadlineViewController.h"

@implementation CPCheckinHandler

static CPCheckinHandler *sharedHandler;

+ (void)initialize
{
    if(!sharedHandler) {
        sharedHandler = [[CPCheckinHandler alloc] init];
    }
}

+ (CPCheckinHandler *)sharedHandler
{
    return sharedHandler;
}

+ (void)presentCheckInListModalFromViewController:(UIViewController *)presentingViewController
{
    // grab the inital view controller of the checkin storyboard
    UINavigationController *checkinNVC = [[UIStoryboard storyboardWithName:@"CheckinStoryboard_iPhone" bundle:nil] instantiateInitialViewController];
    
    // present that VC modally
    [presentingViewController presentModalViewController:checkinNVC animated:YES];
}

+ (void)presentCheckInDetailsModalForVenue:(CPVenue *)venue presentingViewController:(UIViewController *)presentingViewController
{
    // present CheckInDetailsViewController modally (inside a navigation controller), pass the venue we were passed
    CheckInDetailsViewController *checkInDetailsVC = [[UIStoryboard storyboardWithName:@"CheckinStoryboard_iPhone" bundle:nil]
                                                      instantiateViewControllerWithIdentifier:@"CheckinDetailsViewController"];
    checkInDetailsVC.venue = venue;
    
    checkInDetailsVC.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:checkInDetailsVC
                                                                          action:@selector(dismissViewControllerAnimated)];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:checkInDetailsVC];
    [presentingViewController presentModalViewController:navigationController animated:YES];
}

+ (void)presentChangeHeadlineModalFromViewController:(UIViewController *)presentingViewController
{
    // grab the ChangeHeadlineVC from check in storyboard
    ChangeHeadlineViewController *changeHeadlineVC = [[UIStoryboard storyboardWithName:@"CheckinStoryboard_iPhone" bundle:nil]
                                                      instantiateViewControllerWithIdentifier:@"ChangeHeadlineViewController"];
    
    [presentingViewController presentModalViewController:changeHeadlineVC animated:YES];
}

+ (void)handleSuccessfulCheckinToVenue:(CPVenue *)venue checkoutTime:(NSInteger)checkoutTime
{       
    [[self sharedHandler] setCheckedOut];
    // set the NSUserDefault to the user checkout time
    [CPUserDefaultsHandler setCheckoutTime:checkoutTime];
    
    // Save current place to venue defaults as it's used in several places in the app
    [CPUserDefaultsHandler setCurrentVenue:venue];
    
    if (!venue.isNeighborhood) {
        // If this is the user's first check in to this venue and auto-checkins are enabled,
        // ask the user about checking in automatically to this venue in the future
        
        // there are no auto-checkins for WFH - neighborhood venues
        BOOL automaticCheckins = [CPUserDefaultsHandler automaticCheckins];
        
        if (automaticCheckins) {
            // Only show the alert if the current venue isn't currently in the list of monitored venues
            CPVenue *matchedVenue = [[CPGeofenceHandler sharedHandler] venueWithName:venue.name];
            
            if (!matchedVenue) {
                UIAlertView *autoCheckinAlert = [[UIAlertView alloc] initWithTitle:nil
                                                                           message:@"Automatically check in to this venue in the future?"
                                                                          delegate:[CPAppDelegate settingsMenuController]
                                                                 cancelButtonTitle:@"No"
                                                                 otherButtonTitles:@"Yes", nil];
                autoCheckinAlert.tag = AUTOCHECKIN_PROMPT_TAG;
                [autoCheckinAlert show];
            }
        }
    }
}

- (void)setCheckedOut
{
    // set user checkout time to now
    NSInteger checkOutTime = (NSInteger) [[NSDate date] timeIntervalSince1970];
    [CPUserDefaultsHandler setCheckoutTime:checkOutTime];
    
    // nil out the venue in NSUserDefaults
    [CPUserDefaultsHandler setCurrentVenue:nil];
    
    if (self.checkOutTimer) {
        [[self checkOutTimer] invalidate];
        self.checkOutTimer = nil;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userCheckInStateChange" object:nil];
}

+ (void)saveCheckInVenue:(CPVenue *)venue andCheckOutTime:(NSInteger)checkOutTime
{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[self sharedHandler] setCheckedOut];
    [CPUserDefaultsHandler setCheckoutTime:checkOutTime];
    [CPUserDefaultsHandler setCurrentVenue:venue];
    
    // before we update the past venue we need to get its local autocheckin status
    // so that it doesn't get overriden by the call
    CPVenue *staleVenue;
    
    if ((staleVenue = [[CPGeofenceHandler sharedHandler] venueWithName:venue.name])) {
        venue.autoCheckin = staleVenue.autoCheckin;
    }
    
    // only add this neighborhood to the list of past venues if it's not a neighborhood
    if (!venue.isNeighborhood) {
        [[CPGeofenceHandler sharedHandler] updatePastVenue:venue];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userCheckInStateChange" object:nil];
}

+ (void)promptForCheckout
{
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Check Out"
                          message:@"Are you sure you want to be checked out?"
                          delegate:[CPAppDelegate settingsMenuController]
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles: @"Check Out", nil];
    alert.tag = 904;
    [alert show];
}

@end
