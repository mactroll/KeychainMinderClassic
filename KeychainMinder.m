#import "KeychainMinder.h"

@implementation KeychainMinder

//we declare the private function SecKeychainChangePassword
//this is private... so keep that in mind

extern OSStatus SecKeychainChangePassword(SecKeychainRef keychainRef, UInt32 oldPasswordLength, const void* oldPassword, UInt32 newPasswordLength, const void* newPassword);

// the init method, we override it so that we can get some things tested
// before the GUI comes up

+ (void)initialize{
    
    //we check to see if the "CheckLoginKeychain" pref is set to YES (the default)
    //this allows you to get Keychain Minder not to check if that preference is set
    //if the key is set to NO then the app silently quits
    
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"CheckLoginKeychain"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CheckLoginKeychain"]) {
        NSLog(@"Pref file says to check.");}
    else{
        NSLog(@"Pref file says not to check");
        [NSApp terminate: nil];
    }
}

- (id)init
{
	[super init];

	NSLog(@"Checking for locked login keychain");
	
	//we get the login keychain ref here, which we will use in other places
    
	OSStatus getDefaultKeychain;
	getDefaultKeychain = SecKeychainCopyDefault ( &myDefaultKeychain);
	
	//now we check to see if it is locked or not
    
	OSStatus kcstatus ;
	UInt32 mystatus ;
	kcstatus = SecKeychainGetStatus ( myDefaultKeychain, &mystatus );
	
	//cast the UInt32 so we can test it
    
	int myIntStatus = mystatus ;

	// 2 means it's locked, otherwise we bail silently as there's no need for us to do anything
    
	if (myIntStatus == 2 ){
		NSLog(@"Login keychain is locked.");
		[NSApp activateIgnoringOtherApps:YES];
	}
	else{
		NSLog(@"Keychain is unlocked already, so I'll go away now.");
		[NSApp terminate: nil];
	}
	
	return self;
}

- (IBAction)change:(id)sender
{
	OSStatus getDefaultKeychain;
	getDefaultKeychain = SecKeychainCopyDefault ( &myDefaultKeychain);
	
	NSLog(@"Begin changing password");
	OSStatus err;
	NSString *alertText = NULL ;
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	
	//get the passwords from the GUI and cast them to an NSString
    
	NSString *myOldPassword = [oldPass stringValue];
    NSString *myNewPassword = [newPass stringValue];
	
	//check for null password entries, we can't attempt change if one is null
    
	if (myOldPassword.length == 0) {
		alertText = @"Old password is blank.";
		NSLog(@"Old password is blank");
	}
	if (myNewPassword.length == 0) {
		alertText = @"New password is blank.";
		NSLog(@"New password is blank");
	}
    if (myNewPassword == myOldPassword) {
        alertText = @"The passwords are the same";
        NSLog(@"Passwords are the same");
    }
    if (myNewPassword.length < 6) {
        alertText = @"The new password is too short";
        NSLog(@"New password too short");
    }
	
	//now we need to make sure the given password is right
    
    if (CheckPassword(myNewPassword)) {
    }
    else {
        alertText = @"Your new password does not match your login password. Please try again.";
        NSLog(@"Authentication failed.\n");
    }
	
	//if we haven't posted an alert yet, we'll attempt to change the password
	if ( alertText == NULL ) {
	NSLog(@"changing password");
	err = SecKeychainChangePassword ( myDefaultKeychain, (UInt32)myOldPassword.length , [myOldPassword UTF8String], (UInt32)myNewPassword.length, [myNewPassword UTF8String] );
	NSLog(@"changed password");
	if ( err == noErr ) { 
		//if we're done we should go away
		NSLog(@"Password changed successfully");
		[NSApp terminate: nil];
	}
	else if ( err == -25293 ) {
		alertText = @"Bad password. Password change was not successful.";
	}

	//If we don't get a good change, throw an error
	else {
		alertText = @"Password change was not successful. Please try again."; //Vague and mysterious error code: xxx";//, errText ;
		NSLog(@"Change error");
	}
	}

	//set up error sheet if we don't get a good change
    
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Password Change Error"];
	[alert setInformativeText:alertText];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:appWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];

}

- (IBAction)ignore:(id)sender
{	
	//bail if the user doesn't care and hits the ignore button
	NSLog(@"User doesn't care about the password discrepency.");
	[NSApp terminate: nil];
}

- (IBAction)newKeychain:(id)sender;
{
	NSLog(@"User wants a new login keychain");
	
	NSString *alertText = NULL ;
    UInt32 myMaxPathLength = MAXPATHLEN;
	char pathToDefaultKeychain[myMaxPathLength]; // 256 char empty buffer for keychain path. Increase if needed
	OSStatus errNewCreate; // error catch for change
    SecKeychainRef newKeychain;
	//NSString *originalPath; // original keychain path
	NSString *originalPathNoExt = NULL; // original keychain path without .keychain
	int bakCounter = 1; // counter for backed up keychain name
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];

	// first get the path the default keychain using the pointer from before
	errNewCreate = SecKeychainGetPath (
								 myDefaultKeychain,
								 &myMaxPathLength,
								 pathToDefaultKeychain
								 );
	
	if ( errNewCreate != noErr ) {
		alertText = @"Couldn't get path to current keychain.";
	}
	
	//convert
    
    NSString *originalPath = @(pathToDefaultKeychain);
	NSString *newPath = originalPath;
	NSLog(@"the original path is: %@",originalPath);

	NSFileManager *manager = [NSFileManager defaultManager];
	originalPathNoExt = [originalPath stringByDeletingPathExtension];
	originalPathNoExt = [originalPathNoExt stringByAppendingString:@".Backup"];
	
	// this little while loop increments the current path by "1" and checks to see if that nothing else has that path
	
	while ([manager fileExistsAtPath: newPath]) {
		newPath = [[originalPathNoExt stringByAppendingString:[NSString stringWithFormat:@"%d", bakCounter]] stringByAppendingString:@".keychain"];
		NSLog(@"the new path is: %@",newPath);
		bakCounter++;
	}
		
	// Begin process of creating new keychain
	
	//now we need to make sure the given password is right
	
    //get the new password from the GUI and cast them to an NSString
    
    NSString *myNewPassword = [newPass stringValue];
    
    //check for null password entries, we can't attempt change if one is null
    
    if (myNewPassword.length == 0) {
        alertText = @"New password is blank. You need to set this to create a new keychain.";
        NSLog(@"New password is blank");
    }
    
    if (myNewPassword.length < 6) {
        alertText = @"The new password is too short";
        NSLog(@"New password too short");
    }
    
    //now we need to make sure the given password is right
    
    if (CheckPassword(myNewPassword)) {
    }
    else {
        alertText = @"Your new password does not match your login password. Please try again.";
        NSLog(@"Authentication failed.\n");
    }
    
	if ( alertText == NULL ) {

	// convert new string path to const char
	const char * myNewCharPath = [originalPath UTF8String];
		
	// Copy the current keychain to new path - add log item that says what we did!!!

    [[NSFileManager defaultManager] moveItemAtPath:originalPath toPath:newPath error:nil];
	NSLog(@"Your previous keychain has been backed up to %@.",newPath);
	
	// now to delete previous keychain, the one we just copied - this gets rid of keychain reference
	OSStatus changeError = SecKeychainDelete (
								myDefaultKeychain
								);
    CFRelease(myDefaultKeychain);
	
	// create a new keychain
	changeError = SecKeychainCreate (
								myNewCharPath, // path to new keychain
								(UInt32)myNewPassword.length, // length of password for new keychain
								[myNewPassword UTF8String], // password for new keychain
								FALSE, // prompt user for password
								NULL, // initial ACL
								&newKeychain // new keychain ref
								);
	
	// just for fun we'll make sure new keychain is still default
	changeError = SecKeychainSetDefault (
									newKeychain
									);
       
    // would like to use this, but 1) it's private, and 2) it doesn't seem to work well with login keychains that aren't named "login"
    // OSStatus changeError = SecKeychainResetLogin( (UInt32)myNewPassword.length,[myNewPassword UTF8String], TRUE );
        
	if (changeError != 0 ) {
				alertText = @"There may have been errors during the creation of the new keychain.";
	}
	else {
		
		//if we're done we should go away
		NSLog(@"New keychain created successfully");
		[NSApp terminate: nil];
	}
	}
	
	//set up error sheet if we don't get a good change
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Keychain Creation Error"];
	[alert setInformativeText:alertText];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:appWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

	
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	
	//This lets the sheet go away if you hit the button, doesn't do anything just returns
    if (returnCode == NSAlertFirstButtonReturn) {
		return;
    }
}

BOOL CheckPassword(NSString *myPassword) {
    
    //there's a lot of setup here to check a password
    //we create an Authorization Right and then test it
    
    AuthorizationItem myAuthRight;
    myAuthRight.name = "system.login.tty";
    myAuthRight.value = NULL;
    myAuthRight.valueLength = 0;
    myAuthRight.flags = 0;
    AuthorizationRights authRights;
    authRights.count = 1;
    authRights.items = &myAuthRight;
    
    //now to setup the authorization environment
    
    AuthorizationItem authEnvItems[2];
    authEnvItems[0].name = kAuthorizationEnvironmentUsername;
    authEnvItems[0].valueLength = NSUserName().length;
    authEnvItems[0].value = (void *)[NSUserName() UTF8String];
    authEnvItems[0].flags = 0;
    authEnvItems[1].name = kAuthorizationEnvironmentPassword;
    authEnvItems[1].valueLength = myPassword.length;
    authEnvItems[1].value = (void *)[myPassword UTF8String];
    authEnvItems[1].flags = 0;
    AuthorizationEnvironment authEnv;
    authEnv.count = 2;
    authEnv.items = authEnvItems;

    
    //and now to actually do the auth
    
    OSStatus authStatus = AuthorizationCreate(&authRights, &authEnv, kAuthorizationFlagExtendRights, NULL);
    return (authStatus == errAuthorizationSuccess);
    
}

@end
