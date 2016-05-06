//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "PostDetailTableViewController.h"
#import "Post.h"
@import FirebaseDatabase;
@import FirebaseAuth;

static const int kSectionSend = 2;
static const int kSectionComments = 1;
static const int kSectionPost = 0;

@interface PostDetailTableViewController ()
@property (strong, nonatomic) NSMutableArray<FIRDataSnapshot *> *comments;
@property (strong, nonatomic) UITextField *commentField;
@property (strong, nonatomic) Post *post;
@property (strong, nonatomic) FIRDatabaseReference *postRef;
@property (strong, nonatomic) FIRDatabaseReference *commentsRef;
@end

@implementation PostDetailTableViewController

  FIRDatabaseHandle _refHandle;

- (void)viewDidLoad {
  [super viewDidLoad];
  FIRDatabaseReference *ref = [FIRDatabase database].reference;
  self.postRef = [[ref child:@"posts"] child:_postKey];
  self.commentsRef = [[ref child:@"post-comments"] child:_postKey];
  self.comments = [[NSMutableArray alloc] init];
  self.post = [[Post alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
  [self.comments removeAllObjects];
  // Listen for new comments in the Firebase database
  [_commentsRef
                observeEventType:FIRDataEventTypeChildAdded
                withBlock:^(FIRDataSnapshot *snapshot) {
                  [self.comments addObject:snapshot];
                  [self.tableView insertRowsAtIndexPaths:@[
                                                           [NSIndexPath indexPathForRow:[self.comments count] - 1 inSection:1]
                                                           ] withRowAnimation:UITableViewRowAnimationAutomatic];
                }];
  // Listen for deleted comments in the Firebase database
  [_commentsRef
   observeEventType:FIRDataEventTypeChildRemoved
   withBlock:^(FIRDataSnapshot *snapshot) {
     int index = [self indexOfMessage:snapshot];
     [self.comments removeObjectAtIndex:index];
     [self.tableView deleteRowsAtIndexPaths:@[
                                              [NSIndexPath indexPathForRow:index inSection:1]
                                              ] withRowAnimation:UITableViewRowAnimationAutomatic];
   }];

  [_postRef observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
    NSDictionary *postDict = snapshot.value;
    _post.uid = postDict[@"uid"];
    _post.author = postDict[@"author"];
    _post.title = postDict[@"title"];
    _post.body = postDict[@"body"];
    [self.tableView reloadData];
  }];
}

- (int) indexOfMessage:(FIRDataSnapshot *)snapshot {
  int index = 0;
  for (FIRDataSnapshot *comment in _comments) {
    if ([snapshot.key isEqualToString:comment.key]) {
      return index;
    }
    ++index;
  }
  return -1;
}
- (void)viewDidDisappear:(BOOL)animated {
  [self.postRef removeObserverWithHandle:_refHandle];
  [self.commentsRef removeAllObservers];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == kSectionPost || section == kSectionSend ) {
    return 1;
  } else if (section == kSectionComments) {
    return [_comments count];
  }
  NSAssert(NO, @"Unexpected section");
  return 0;
}

- (IBAction)didTapSend:(id)sender {
  NSString *uid = [FIRAuth auth].currentUser.uid;
  [[[[FIRDatabase database].reference child:@"users"] child:uid] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
    NSDictionary *user = snapshot.value;
    NSString *username = user[@"username"];
    NSDictionary *comment = @{@"uid": uid,
                              @"author": username,
                              @"text": _commentField.text};
    [[_commentsRef childByAutoId] setValue:comment];
    _commentField.text = @"";
  }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell;
  if (indexPath.section == kSectionPost) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"post"];
    UILabel *authorLabel = [(UILabel *) cell viewWithTag:2];
    UILabel *title = [(UILabel *) cell viewWithTag:3];
    UITextView *body = [(UITextView *) cell viewWithTag:6];
    authorLabel.text = _post.author;
    title.text = _post.title;
    body.text = _post.body;
  } else if (indexPath.section == kSectionComments) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"comment"];
    NSDictionary *comment = _comments[indexPath.row].value;
    cell.textLabel.text = comment[@"author"];
    cell.detailTextLabel.text = comment[@"text"];
  } else if (indexPath.section == kSectionSend) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"send"];
    _commentField = [(UITextField *) cell viewWithTag:7];
  }
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == kSectionPost) {
    return 150;
  }
  return 50;
}

@end
