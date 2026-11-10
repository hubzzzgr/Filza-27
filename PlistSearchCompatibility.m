#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// The equally sized class name replaces ONLY TGPlistViewController.nib's
// deprecated class record. Never initialize or subclass UISearchDisplayController.
@interface FZPlistSearchControllerXX : NSObject <UISearchResultsUpdating, UISearchControllerDelegate, UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, weak) UIViewController *searchContentsController;
@property(nonatomic, weak) id delegate;
@property(nonatomic, weak) id<UITableViewDataSource> searchResultsDataSource;
@property(nonatomic, weak) id<UITableViewDelegate> searchResultsDelegate;
@property(nonatomic, strong) UISearchController *modern;
@property(nonatomic, strong) UITableViewController *results;
@property(nonatomic) BOOL displaysSearchBarInNavigationBar;
@property(nonatomic, copy) NSString *searchResultsTitle;
@property(nonatomic, copy) NSArray<NSIndexPath *> *matches;
@property(nonatomic) BOOL notifiedLoad;
- (void)attach;
@end

static char plistSearchKey;
@implementation FZPlistSearchControllerXX
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (instancetype)initWithSearchBar:(UISearchBar *)bar contentsController:(UIViewController *)owner {
    self = [super init];
    if (self) { self.searchContentsController = owner; }
    return self;
}
- (void)ensureModern {
    if (_modern) return;
    _results = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    _modern = [[UISearchController alloc] initWithSearchResultsController:_results];
    _modern.searchResultsUpdater = self;
    _modern.delegate = self;
    _modern.obscuresBackgroundDuringPresentation = NO;
}
- (UISearchBar *)searchBar { [self ensureModern]; return self.modern.searchBar; }
- (UITableView *)searchResultsTableView { [self ensureModern]; return self.results.tableView; }
- (BOOL)isActive { return self.modern.isActive; }
- (void)setActive:(BOOL)active { [self setActive:active animated:NO]; }
- (void)setActive:(BOOL)active animated:(BOOL)animated {
    [self attach]; self.modern.active = active;
}
- (void)setSearchContentsController:(UIViewController *)owner {
    _searchContentsController = owner;
    if (owner.isViewLoaded) [self attach];
}
- (void)setSearchResultsDataSource:(id<UITableViewDataSource>)source {
    _searchResultsDataSource = source;
    self.searchResultsTableView.dataSource = source;
}
- (void)setSearchResultsDelegate:(id<UITableViewDelegate>)delegate {
    _searchResultsDelegate = delegate;
    self.searchResultsTableView.delegate = delegate;
}
- (void)awakeFromNib { [super awakeFromNib]; [self attach]; }
- (void)attach {
    [self ensureModern];
    UIViewController *owner = self.searchContentsController;
    if (!owner || !owner.isViewLoaded) return;
    if (!self.delegate) self.delegate = owner;
    BOOL legacyFilter = [self.delegate respondsToSelector:NSSelectorFromString(@"searchDisplayController:shouldReloadTableForSearchString:")];
    self.results.tableView.dataSource = legacyFilter ? (self.searchResultsDataSource ?: (id)owner) : self;
    self.results.tableView.delegate = legacyFilter ? (self.searchResultsDelegate ?: (id)owner) : self;
    if (!self.notifiedLoad) {
        self.notifiedLoad = YES;
        [self notifyTable:@"searchDisplayController:didLoadSearchResultsTableView:"];
    }
    owner.definesPresentationContext = YES;
    owner.navigationItem.searchController = self.modern;
    owner.navigationItem.hidesSearchBarWhenScrolling = NO;
}
- (void)notify:(NSString *)name {
    SEL action = NSSelectorFromString(name);
    if ([self.delegate respondsToSelector:action])
        ((void(*)(id,SEL,id))objc_msgSend)(self.delegate, action, self);
}
- (void)notifyTable:(NSString *)name {
    SEL action = NSSelectorFromString(name);
    if ([self.delegate respondsToSelector:action])
        ((void(*)(id,SEL,id,id))objc_msgSend)(self.delegate, action, self, self.searchResultsTableView);
}
- (void)willPresentSearchController:(UISearchController *)controller {
    [self notify:@"searchDisplayControllerWillBeginSearch:"];
    [self notifyTable:@"searchDisplayController:willShowSearchResultsTableView:"];
}
- (void)didPresentSearchController:(UISearchController *)controller {
    [self notify:@"searchDisplayControllerDidBeginSearch:"];
    [self notifyTable:@"searchDisplayController:didShowSearchResultsTableView:"];
}
- (void)willDismissSearchController:(UISearchController *)controller {
    [self notify:@"searchDisplayControllerWillEndSearch:"];
    [self notifyTable:@"searchDisplayController:willHideSearchResultsTableView:"];
}
- (void)didDismissSearchController:(UISearchController *)controller {
    [self notify:@"searchDisplayControllerDidEndSearch:"];
    [self notifyTable:@"searchDisplayController:didHideSearchResultsTableView:"];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
    SEL filter = NSSelectorFromString(@"searchDisplayController:shouldReloadTableForSearchString:");
    BOOL reload = YES;
    if ([self.delegate respondsToSelector:filter])
        reload = ((BOOL(*)(id,SEL,id,id))objc_msgSend)(self.delegate,filter,self,controller.searchBar.text ?: @"");
    if (![self.delegate respondsToSelector:filter]) [self findVisibleTreeRows:controller.searchBar.text ?: @""];
    if (reload) [self.searchResultsTableView reloadData];
}
- (UITableView *)originalTable {
    SEL selector = NSSelectorFromString(@"treeTable");
    id owner = self.searchContentsController;
    return [owner respondsToSelector:selector] ? ((id(*)(id,SEL))objc_msgSend)(owner,selector) : nil;
}
- (NSString *)textInView:(UIView *)view {
    NSMutableString *text = [NSMutableString new];
    if ([view isKindOfClass:UILabel.class]) [text appendString:((UILabel *)view).text ?: @""];
    for (UIView *child in view.subviews) [text appendFormat:@" %@", [self textInView:child]];
    return text;
}
- (void)findVisibleTreeRows:(NSString *)query {
    UITableView *table = [self originalTable];
    id<UITableViewDataSource> source = self.searchResultsDataSource ?: (id)self.searchContentsController;
    NSMutableArray *paths = [NSMutableArray new];
    if (!table || !source) { self.matches = @[]; return; }
    NSInteger sections = [source respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [source numberOfSectionsInTableView:table] : 1;
    if (table) for (NSInteger section = 0; section < sections; section++) {
        NSInteger count = [source tableView:table numberOfRowsInSection:section];
        for (NSInteger row = 0; row < count; row++) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [source tableView:table cellForRowAtIndexPath:path];
            if (!query.length || [[self textInView:cell] localizedCaseInsensitiveContainsString:query]) [paths addObject:path];
        }
    }
    self.matches = paths;
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.matches.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    id<UITableViewDataSource> source = self.searchResultsDataSource ?: (id)self.searchContentsController;
    return [source tableView:[self originalTable] cellForRowAtIndexPath:self.matches[path.row]];
}
- (void)openMatch:(NSIndexPath *)path accessory:(BOOL)accessory {
    if (path.row >= (NSInteger)self.matches.count) return;
    NSIndexPath *original = self.matches[path.row];
    void (^open)(void) = ^{
        self.modern.active = NO;
        UITableView *tree = [self originalTable];
        if (!tree || original.section >= tree.numberOfSections || original.row >= [tree numberOfRowsInSection:original.section]) return;
        [tree scrollToRowAtIndexPath:original atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        [tree selectRowAtIndexPath:original animated:NO scrollPosition:UITableViewScrollPositionNone];
        id target = self.searchResultsDelegate ?: (id)self.searchContentsController;
        SEL action = accessory ? @selector(tableView:accessoryButtonTappedForRowWithIndexPath:) : @selector(tableView:didSelectRowAtIndexPath:);
        if ([target respondsToSelector:action]) ((void(*)(id,SEL,id,id))objc_msgSend)(target,action,tree,original);
    };
    if (self.modern.presentingViewController) [self.modern dismissViewControllerAnimated:NO completion:open];
    else open();
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [self openMatch:path accessory:NO]; }
- (void)tableView:(UITableView *)table accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)path { [self openMatch:path accessory:YES]; }

@end

static id PlistSearchGet(id owner, SEL cmd) {
    id bridge = objc_getAssociatedObject(owner, &plistSearchKey);
    if (!bridge) {
        bridge = [FZPlistSearchControllerXX new];
        objc_setAssociatedObject(owner, &plistSearchKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [bridge setSearchContentsController:owner];
        [bridge setDelegate:owner];
    }
    return bridge;
}
static void PlistSearchSet(id owner, SEL cmd, id bridge) {
    if (![bridge isKindOfClass:FZPlistSearchControllerXX.class]) return;
    objc_setAssociatedObject(owner, &plistSearchKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [bridge setSearchContentsController:owner];
}
static IMP plistOriginalLoad;
static void PlistSearchLoad(id owner, SEL cmd) {
    ((void(*)(id,SEL))plistOriginalLoad)(owner,cmd);
    [PlistSearchGet(owner, NULL) attach];
}
__attribute__((constructor)) static void InstallPlistSearchCompatibility(void) {
    Class cls = NSClassFromString(@"TGPlistViewController");
    if (!cls) return;
    class_replaceMethod(cls, NSSelectorFromString(@"searchDisplayController"), (IMP)PlistSearchGet, "@@:");
    class_replaceMethod(cls, NSSelectorFromString(@"setSearchDisplayController:"), (IMP)PlistSearchSet, "v@:@");
    Method load = class_getInstanceMethod(cls, @selector(viewDidLoad));
    if (load) {
        plistOriginalLoad = method_getImplementation(load);
        class_replaceMethod(cls,@selector(viewDidLoad),(IMP)PlistSearchLoad,method_getTypeEncoding(load));
    }
}
