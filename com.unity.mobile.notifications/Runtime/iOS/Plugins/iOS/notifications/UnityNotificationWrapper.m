//
//  UnityNotificationWrapper.m
//  iOS.notifications
//
//  Created by Paulius on 26/07/2018.
//  Copyright © 2018 Unity Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "UnityNotificationManager.h"
#import "UnityNotificationWrapper.h"

AuthorizationRequestResponse req_callback;
DATA_CALLBACK g_notificationReceivedCallback;
DATA_CALLBACK g_remoteNotificationCallback;

void onNotificationReceived(struct iOSNotificationData* data)
{
    printf("\n - onNotificationReceived /n");
    if (g_notificationReceivedCallback != NULL)
        g_notificationReceivedCallback(data);
    
}

void onRemoteNotificationReceived(struct iOSNotificationData* data)
{
    printf("\n - onRemoteNotificationReceived /n");
    if (g_remoteNotificationCallback != NULL)
        g_remoteNotificationCallback(data);
}

void _SetAuthorizationRequestReceivedDelegate(AUTHORIZATION_CALBACK callback)
{
    NSLog(@"UnityPlugin: _SetAuthorizationRequestReceivedDelegate(%p)", callback);
    
    req_callback = callback;
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    manager.onAuthorizationCompletionCallback = req_callback;

}

//void onAuthorizationRequestCompletion(BOOL granted)
//{
//    req_callback(granted);
//}


void _SetNotificationReceivedDelegate(DATA_CALLBACK callback)
{
    NSLog(@"UnityPlugin: _SetNotificationReceivedDelegate(%p)", callback);
    g_notificationReceivedCallback = callback;
    
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    manager.onNotificationReceivedCallback = &onNotificationReceived;
}

void _SetRemoteNotificationReceivedDelegate(DATA_CALLBACK callback)
{
    NSLog(@"UnityPlugin: _SetRemoteNotificationReceivedDelegate(%p)", callback);
    g_remoteNotificationCallback = callback;
    
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    manager.onCatchReceivedRemoteNotificationCallback = &onRemoteNotificationReceived;
}


void _RequestAuthorization(int options, BOOL registerRemote)
{//UNAuthorizationOptionSound + UNAuthorizationOptionAlert + UNAuthorizationOptionBadge
    
    [[UnityNotificationManager sharedInstance] requestAuthorization:(UNAuthorizationOptionSound + UNAuthorizationOptionAlert + UNAuthorizationOptionBadge) : YES];
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = [UnityNotificationManager sharedInstance];
}

void _ScheduleLocalNotification(struct iOSNotificationData* data)
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    [manager requestAuthorization:(UNAuthorizationOptionSound + UNAuthorizationOptionAlert + UNAuthorizationOptionBadge) : YES];
    
    assert(manager.onNotificationReceivedCallback != NULL);
    
    NSDictionary *userInfo = @{
                                 @"showInForeground" : @(data->showInForeground),
                                 @"showInForegroundPresentationOptions" : [NSNumber numberWithInteger:data->showInForegroundPresentationOptions]
                                 };

    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = [NSString localizedUserNotificationStringForKey: [NSString stringWithUTF8String: data->title] arguments:nil];
    content.body = [NSString localizedUserNotificationStringForKey: [NSString stringWithUTF8String: data->body] arguments:nil];
    content.badge = [NSNumber numberWithInt:data->badge];
    content.userInfo = userInfo;
    
    if (data->subtitle != NULL)
        content.subtitle = [NSString localizedUserNotificationStringForKey: [NSString stringWithUTF8String: data->subtitle] arguments:nil];
    
    if (data->categoryIdentifier != NULL)
        content.categoryIdentifier = [NSString stringWithUTF8String:data->categoryIdentifier];
    
    if (data->threadIdentifier != NULL)
        content.threadIdentifier = [NSString stringWithUTF8String:data->threadIdentifier];
    
    // TODO add way to specify
    content.sound = [UNNotificationSound defaultSound];
    
    // Deliver the notification in five seconds.
//    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
//                                                  triggerWithTimeInterval:data->timeTriggerFireTime repeats: repeats];
    
    UNNotificationTrigger* trigger;
    
    if ( data->triggerType == 0)
    {
        trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:data->timeTriggerInterval repeats: data -> repeats];
    }
    else if ( data->triggerType == 1)
    {
        NSDateComponents* date = [[NSDateComponents alloc] init];
        if ( data->calendarTriggerYear >= 0)
            date.year = data->calendarTriggerYear;
        if (data->calendarTriggerMonth >= 0)
            date.hour = data->calendarTriggerMonth;
        if (data->calendarTriggerDay >= 0)
            date.hour = data->calendarTriggerDay;
        if (data->calendarTriggerHour >= 0)
            date.hour = data->calendarTriggerHour;
        if (data->calendarTriggerMinute >= 0)
            date.hour = data->calendarTriggerMinute;
        if (data->calendarTriggerSecond >= 0)
            date.hour = data->calendarTriggerSecond;
        
        trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:date repeats:data->repeats];
    }
    else if ( data->triggerType == 2)
    {
        if (NSClassFromString(@"CLLocationManager"))
        {
            CLLocationCoordinate2D center = CLLocationCoordinate2DMake(data->locationTriggerCenterX, data->locationTriggerCenterY);
            
            CLCircularRegion* region = [[CLCircularRegion alloc] initWithCenter:center
                                                                         radius:data->locationTriggerRadius identifier:@"Headquarters"];
            region.notifyOnEntry = data->locationTriggerNotifyOnEntry;
            region.notifyOnExit = data->locationTriggerNotifyOnExit;
            
            trigger = [UNLocationNotificationTrigger triggerWithRegion:region repeats:NO];
        }
        else
        {
            //TODO Handle
        }
    }
    else
    {
        //Should throw an error TODO to managed.
        return;
    }

    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:
                                      [NSString stringWithUTF8String:data->identifier] content:content trigger:trigger];
    
    // Schedule the notification.
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        
        if (error != NULL)
            NSLog(@"%@",[error localizedDescription]);
        
        [manager updateScheduledNotificationList];

    }];
}

NotificationSettingsData* _GetNotificationSettings()
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    return [UnityNotificationManager UNNotificationSettingsToNotificationSettingsData:[manager cachedNotificationSettings]];
}

int _GetScheduledNotificationDataCount()
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    return [manager.cachedPendingNotificationRequests count];
}
iOSNotificationData* _GetScheduledNotificationDataAt(int index)
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];

    if (index >= [manager.cachedPendingNotificationRequests count])
        return NULL;
    
    UNNotificationRequest * request = manager.cachedPendingNotificationRequests[index];
    
    
    return [UnityNotificationManager UNNotificationRequestToiOSNotificationData : request];
}

int _GetDeliveredNotificationDataCount()
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    return [manager.cachedDeliveredNotifications count];
}
iOSNotificationData* _GetDeliveredNotificationDataAt(int index)
{
    UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
    
    if (index >= [manager.cachedDeliveredNotifications count])
        return NULL;
    
    UNNotification * notification = manager.cachedDeliveredNotifications[index];
    
    return [UnityNotificationManager UNNotificationToiOSNotificationData: notification];
}


void _RemoveScheduledNotification(const char* identifier)
{
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[[NSString stringWithUTF8String:identifier]]];
    [[UnityNotificationManager sharedInstance] updateScheduledNotificationList];
}


void _RemoveAllScheduledNotifications()
{
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllPendingNotificationRequests];
    [[UnityNotificationManager sharedInstance] updateScheduledNotificationList];
}

void _RemoveDeliveredNotification(const char* identifier)
{
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeDeliveredNotificationsWithIdentifiers:@[[NSString stringWithUTF8String:identifier]]];
    [[UnityNotificationManager sharedInstance] updateDeliveredNotificationList];
}

void _RemoveAllDeliveredNotifications()
{
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];
    [[UnityNotificationManager sharedInstance] updateDeliveredNotificationList];
}