/* KeychainMinder */

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <DirectoryService/DirectoryService.h>
#import <OpenDirectory/OpenDirectory.h>

// Checks for a valid password

BOOL CheckPassword(NSString *Password);

@interface KeychainMinder : NSObject
{
    IBOutlet NSTextField *newPass;
    IBOutlet NSTextField *oldPass;
//  IBOutlet NSTextField *alertText;
	SecKeychainRef myDefaultKeychain;
	IBOutlet NSWindow *appWindow;
}
- (IBAction)change:(id)sender;
- (IBAction)ignore:(id)sender;
- (IBAction)newKeychain:(id)sender;

@end
