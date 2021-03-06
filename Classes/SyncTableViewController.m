//
//  SyncTableViewController.m
//  Recipes
//
//  Created by Jimi Xenidis on 12/13/14.
//
//

#import <CDTIncrementalStore.h>

#import "SyncTableViewController.h"
#import "RecipeListTableViewController.h"

@interface SyncTableViewController () <UITextFieldDelegate, CDTReplicatorDelegate>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *syncButton;

@property (weak, nonatomic) IBOutlet UITextField *dbnameTF;
@property (weak, nonatomic) IBOutlet UITextField *userTF;
@property (weak, nonatomic) IBOutlet UITextField *passwordTF;
@property (weak, nonatomic) IBOutlet UITextField *hostnameTF;
@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *serverInfo;

@property (weak, nonatomic) IBOutlet UITableViewCell *testCell;
@property (nonatomic) BOOL serverVerified;


@property (strong, nonatomic) IBOutletCollection(UITableViewCell) NSArray *options;
@property (nonatomic) NSInteger syncSelection;

@property (weak, nonatomic) IBOutlet UIProgressView *progress;

@property (strong, nonatomic) NSURL *remoteURL;

@property (strong, nonatomic) CDTReplicator *strongReplicator;

@end

@implementation SyncTableViewController

#pragma mark - Constants and Enums

NSString *const kUserSettingUserKey = @"user";
NSString *const kUserSettingPasswordKey = @"password";
NSString *const kUserSettingHostnameKey = @"hostname";
NSString *const kUserSettingSyncKey = @"syncSelection";
NSString *const kUserSettingDBnameKey = @"databaseName";

typedef NS_ENUM(NSInteger, SyncSection) {
    SyncSectionOptions,
    SyncSectionServer,
    SyncSectionStatus,
};

// These match the table position.
typedef NS_ENUM(NSInteger, SyncOptions) {
    SyncOptionsInitialize,
    SyncOptionsSynchronize,
    SyncOptionsPush,
    SyncOptionsPull,
};

// These match the table position.
typedef NS_ENUM(NSInteger, SyncServer) {
    SyncServerDBName,
    SyncServerUser,
    SyncServerPassword,
    SyncServerHostname,
    SyncServerCheck,
};

#pragma mark - Utils

- (RecipeListTableViewController *)getRecipeListViewController
{
    // get the NSManagedObjectContext from the RecipeListTableViewController
    // wow.. this is amazing!!!
    UITabBarController *tabBarController = (UITabBarController *)self.tableView.window.rootViewController;
    UINavigationController *navController = tabBarController.viewControllers[0];

    RecipeListTableViewController *recipeListVC = (RecipeListTableViewController *)[navController.viewControllers firstObject];

    return recipeListVC;
}

- (NSManagedObjectContext *)getManagedObjectContext
{
    RecipeListTableViewController *rltvc = [self getRecipeListViewController];
    NSManagedObjectContext *moc = rltvc.managedObjectContext;
    return moc;
}

- (NSPersistentStoreCoordinator *)getPersistentStoreCoordinator
{
    NSManagedObjectContext *moc = [self getManagedObjectContext];
    NSPersistentStoreCoordinator *psc = moc.persistentStoreCoordinator;
    return psc;
}

- (void)refreshRecipeListTableView
{
    // This is heavy handed, but it works
    RecipeListTableViewController *rltvc = [self getRecipeListViewController];
    [NSFetchedResultsController deleteCacheWithName:nil];
    rltvc.fetchedResultsController = nil;
    [rltvc viewDidLoad];
}

- (CDTIncrementalStore *)getIncrementalStore
{
    NSPersistentStoreCoordinator *psc = [self getPersistentStoreCoordinator];
    NSArray *stores = [CDTIncrementalStore storesFromCoordinator:psc];
    CDTIncrementalStore *myIS = [stores firstObject];
    return myIS;
}

- (void)reportIssue:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1,2);
{
    va_list ap;

    // Initialize a variable argument list.
    va_start (ap, fmt);

    NSString *s = [[NSString alloc] initWithFormat:fmt locale:nil arguments:ap];

    va_end(ap);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Issue"
                                                                   message:s
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) { }];

    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];

}

-(void)markServerUnknown
{
    self.serverVerified = NO;
    self.testCell.detailTextLabel.text = @"Unknown";
    self.testCell.detailTextLabel.textColor = [UIColor redColor];
}

- (BOOL)checkRemoteURL:(NSURL *)url
{
    [self markServerUnknown];

    NSError *err = nil;
    NSData *obj = [NSData dataWithContentsOfURL:url
                                        options:0
                                          error:&err];
    if (!obj) {
        NSString *sum = @"Network error";
        [self reportIssue:@"%@: %@", sum, err];
        self.testCell.detailTextLabel.text = sum;
        return NO;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:obj
                                                         options:0
                                                           error:&err];
    if (!json) {
        NSString *sum = @"Fetch Error";
        [self reportIssue:@"%@: %@", sum, err];
        self.testCell.detailTextLabel.text = sum;
        return NO;
    }
    if (json[@"error"]) {
        NSString *sum = @"Server Error";
        [self reportIssue:@"%@: %@", sum, json[@"reason"]];
        self.testCell.detailTextLabel.text = sum;
        return NO;
    }

    self.testCell.detailTextLabel.text = @"ok";
    self.testCell.detailTextLabel.textColor = [UIColor greenColor];
    self.serverVerified = YES;
    self.remoteURL = url;
    [self updateSyncView];
    return YES;
}

- (void)syncOptionAsk:(NSString *)msg
              handler:(void (^)(UIAlertAction *action))handler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Are You Sure?"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action) {}];
    [alert addAction:cancel];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"I'm Sure" style:UIAlertActionStyleDestructive
                                               handler:handler];

    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
    
}

#pragma mark - Intitialize CoreData

- (void)syncOptionInitialize
{

    NSError *err = nil;

    RecipeListTableViewController *rlvc = [self getRecipeListViewController];
    NSManagedObjectContext *moc = rlvc.managedObjectContext;

    // copy the default store (with a pre-populated data) into our Documents folder
    NSString *cannedSQLPath = [[NSBundle mainBundle] pathForResource:@"Recipes" ofType:@"sqlite"];
    NSURL *cannedURL = [NSURL fileURLWithPath:cannedSQLPath];

    NSPersistentStoreCoordinator *psc = moc.persistentStoreCoordinator;

    if (![moc save:&err]) {
        [self reportIssue:@"save before delete failed"];
        return;
    }

    // remove all the current stores
    for (NSPersistentStore *ps in psc.persistentStores) {
        if (![psc removePersistentStore:ps error:&err]) {
            NSLog(@"no remove: %@", err);
            return;
        }
    }

    moc = [NSManagedObjectContext new];
    [moc setPersistentStoreCoordinator:psc];
    rlvc.managedObjectContext = moc;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *dir =
    [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];

    NSURL *storeURL = [dir URLByAppendingPathComponent:self.dbnameTF.text];

    // remove the entire database directory
    if (![fm removeItemAtURL:storeURL error:&err]) {
        if (err.code != NSFileNoSuchFileError) {
            [self reportIssue:@"removal of database directory failed: %@", err];
            return;
        }
    }

    NSDictionary *opts = @{
                           NSPersistentStoreRemoveUbiquitousMetadataOption: @YES,
                           NSMigratePersistentStoresAutomaticallyOption: @YES,
                           NSInferMappingModelAutomaticallyOption: @YES
                           };
    NSPersistentStore *cannedStore = [psc addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:cannedURL
                                                             options:opts
                                                               error:&err];
    if (!cannedStore) {
        [self reportIssue:@"could not get fromStore: %@", err];
        return;
    }

    NSString *type = [CDTIncrementalStore type];
    NSPersistentStore *theStore = [psc migratePersistentStore:cannedStore
                                                        toURL:storeURL
                                                      options:nil
                                                     withType:type
                                                        error:&err];

    if (!theStore) {
        [self reportIssue:@"could not get fromStore: %@", err];
        return;
    }
    [self refreshRecipeListTableView];
}

#pragma mark - Replication Ops
/**
 * Called when the replicator changes state.
 */
- (void)replicatorDidChangeState:(CDTReplicator *)replicator
{
    NSString *state;
    switch (replicator.state) {
        case CDTReplicatorStatePending:
            state = @"CDTReplicatorStatePending";
            break;
        case CDTReplicatorStateStarted:
            state = @"CDTReplicatorStateStarted";
            break;
        case CDTReplicatorStateStopped:
            state = @"CDTReplicatorStateStopped";
            break;
        case CDTReplicatorStateStopping:
            state = @"CDTReplicatorStateStopping";
            break;
        case CDTReplicatorStateComplete:
            state = @"CDTReplicatorStateComplete";
            break;
        case CDTReplicatorStateError:
            state = @"CDTReplicatorStateError";
            break;
        default:
            state = @"unknown replicator state";
            break;
    }
    NSLog(@"replicator state[%@]: %@", @(replicator.state), state);
}

/**
 * Called whenever the replicator changes progress
 */
- (void)replicatorDidChangeProgress:(CDTReplicator *)replicator
{
    float cent;
    if (replicator.changesTotal) {
        cent = 1.0;
    } else {
        cent = (float)replicator.changesProcessed / (float)replicator.changesTotal;
    }

    [self.progress setProgress:cent animated:YES];
}

/**
 * Called when a state transition to COMPLETE or STOPPED is
 * completed.
 */
- (void)replicatorDidComplete:(CDTReplicator *)replicator
{
    [self.progress setProgress:1.0 animated:YES];
    self.syncButton.enabled = YES;
    [self refreshRecipeListTableView];

    self.syncButton.enabled = self.serverVerified;
    self.strongReplicator = nil;
}

/**
 * Called when a state transition to ERROR is completed.
 */
- (void)replicatorDidError:(CDTReplicator *)replicator info:(NSError *)info
{
    [self reportIssue:@"Replicator error: %@", info];
    [self.progress setProgress:1.0 animated:YES];
    self.syncButton.enabled = self.serverVerified;
    self.strongReplicator = nil;
}


- (void)syncOptionsPush
{
    NSError *err = nil;

    self.syncButton.enabled = NO;
    [self.progress setProgress:0. animated:YES];


    CDTIncrementalStore *myIS = [self getIncrementalStore];
    CDTISReplicator *pusherIS = [myIS replicatorThatPushesToURL:self.remoteURL withError:&err];
    CDTReplicator *pusher = pusherIS.replicator;

    pusher.delegate = self;

    if ([pusher startWithError:&err]) {
        self.strongReplicator = pusher;
        return;
    }
    [self reportIssue:@"Push Failed with error: %@", err];
    self.syncButton.enabled = self.serverVerified;

}

- (void)syncOptionsPull
{
    NSError *err = nil;

    self.syncButton.enabled = NO;
    [self.progress setProgress:0. animated:YES];

    CDTIncrementalStore *myIS = [self getIncrementalStore];
    CDTISReplicator *pullerIS = [myIS replicatorThatPullsFromURL:self.remoteURL withError:&err];
    CDTReplicator *puller = pullerIS.replicator;

    puller.delegate = self;

    if ([puller startWithError:&err]) {
        self.strongReplicator = puller;
        return;
    }
    [self reportIssue:@"Pull Failed with error: %@", err];
    self.syncButton.enabled = self.serverVerified;
}

#pragma UI Controls

- (IBAction)syncPressed:(id)sender
{
    __typeof(self) __weak weakSelf = self;
    switch (self.syncSelection) {
        case SyncOptionsInitialize: {
            [self syncOptionAsk:@"This will remove the current contents of the local database."
                        handler:^(UIAlertAction * action) {
                            [weakSelf syncOptionInitialize];
                        }];
            break;
        }

        case SyncOptionsSynchronize: {
            [self syncOptionAsk:@"This will synchronize the local contents with the server contents... one day"
                        handler:^(UIAlertAction * action) {
                            NSLog(@"no yet");
                        }];
            break;
        }

        case SyncOptionsPush: {
            [self syncOptionsPush];
            break;
        }

        case SyncOptionsPull: {
            [self syncOptionsPull];
            break;
        }
        default:
            return;
    }
}

- (void)updateSyncView
{
    if (self.syncSelection == SyncOptionsInitialize) {
        self.syncButton.enabled = YES;
        return;
    }

    if (self.serverVerified) {
        self.syncButton.enabled = YES;
        return;
    }
    self.syncButton.enabled = NO;
}

- (void)updateSyncOptions:(NSInteger)sel
{
    self.syncSelection = sel;
    for (UITableViewCell *opts in self.options) {
        if (opts.tag == sel) {
            opts.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            opts.accessoryType = UITableViewCellAccessoryNone;
        }
    }

    [self updateSyncView];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:@(sel) forKey:kUserSettingSyncKey];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self markServerUnknown];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

    switch (textField.tag) {
        case SyncServerDBName:
            [defs setObject:textField.text forKey:kUserSettingDBnameKey];
            break;
        case SyncServerUser:
            [defs setObject:textField.text forKey:kUserSettingUserKey];
            break;
        case SyncServerPassword:
            // cipher?
            [defs setObject:textField.text forKey:kUserSettingPasswordKey];
            break;
        case SyncServerHostname:
            [defs setObject:textField.text forKey:kUserSettingHostnameKey];
            break;
        default:
            return YES;
    }
    [defs synchronize];

    return YES;
}

- (void)textFieldDidEndEditingHandler:(NSNotification *)note
{
    if ([note.name isEqualToString:UITextFieldTextDidChangeNotification]) {
        [self markServerUnknown];
        return;
    }

    UITextField *textField = (UITextField *)note.object;
    [self textFieldShouldReturn:textField];
}

- (UITextField *)getTextFieldFromTag:(NSInteger)tag
{
    switch (tag) {
        case SyncServerDBName:
            return self.dbnameTF;
        case SyncServerUser:
            return self.userTF;
        case SyncServerPassword:
            return self.passwordTF;
        case SyncServerHostname:
            return self.hostnameTF;
    }
    return nil;
}

- (void)updateSyncServerCheck:(NSInteger)tag
{
    // not sure what I'll do here, if anything.
    if (tag != SyncServerCheck) {
        return;
    }
    NSString *s = [NSString stringWithFormat:@"https://%@:%@@%@/%@",
                   self.userTF.text,
                   self.passwordTF.text,
                   self.hostnameTF.text,
                   self.dbnameTF.text];
    NSURL *url = [NSURL URLWithString:s];

    [self checkRemoteURL:url];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case SyncSectionOptions:
            [self updateSyncOptions:indexPath.row];
            break;
        case SyncSectionServer:
            [self updateSyncServerCheck:indexPath.row];
            break;
        default:
            break;
    }
}

- (void)userSettings
{
    // Add an Observer when all text fields are done
    NSNotificationCenter *note = [NSNotificationCenter defaultCenter];
    [note addObserver:self
             selector:@selector(textFieldDidEndEditingHandler:)
                 name:UITextFieldTextDidEndEditingNotification
               object:nil];
    [note addObserver:self
             selector:@selector(textFieldDidEndEditingHandler:)
                 name:UITextFieldTextDidChangeNotification
               object:nil];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

    self.dbnameTF.text = [defs stringForKey:kUserSettingDBnameKey];
    self.dbnameTF.tag = SyncServerDBName;
    self.dbnameTF.delegate = self;

    self.hostnameTF.text = [defs stringForKey:kUserSettingHostnameKey];
    self.hostnameTF.tag = SyncServerHostname;
    self.hostnameTF.delegate = self;

    self.userTF.text = [defs stringForKey:kUserSettingUserKey];
    self.userTF.tag = SyncServerUser;
    self.userTF.delegate = self;

    // encrypt?
    self.passwordTF.text = [defs stringForKey:kUserSettingPasswordKey];
    self.passwordTF.tag = SyncServerPassword;
    self.passwordTF.delegate = self;

    self.syncSelection = [defs integerForKey:kUserSettingSyncKey];
}

- (void)viewDidLayoutSubviews
{
    // storyboard has the checks set so we clear them.
    for (UITableViewCell *opts in self.options) {
        opts.accessoryType = UITableViewCellAccessoryNone;
    }

    [self updateSyncOptions:self.syncSelection];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.progress setProgress:0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // It would be bad if this was not 0
    assert(SyncOptionsInitialize == 0);
    [self userSettings];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // remove our observer
    NSNotificationCenter *note = [NSNotificationCenter defaultCenter];
    [note removeObserver:self];

}

@end
