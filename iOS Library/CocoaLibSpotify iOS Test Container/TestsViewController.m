//
//  TestsViewController.m
//  CocoaLibSpotify iOS Library
//
//  Created by Daniel Kennett on 02/10/2012.
//
//

#import "TestsViewController.h"
#import "SPTests.h"
#import "TestProgressCell.h"

@interface TestsViewController ()

@end

@implementation TestsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
		[self addObserver:self forKeyPath:@"tests" options:0 context:nil];
		self.title = @"Running tests…";
    }
    return self;
}

@synthesize tests;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"tests"]) {
        [self.tableView reloadData];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return self.tests.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[[self.tests objectAtIndex:section] uiPlaceholders] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    TestProgressCell *cell = (TestProgressCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];

	if (cell == nil) {
		cell = [[TestProgressCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	}
    // Configure the cell...

	SPTests *test = [self.tests objectAtIndex:indexPath.section];
	SPTestUIPlaceholder *placeholder = [test.uiPlaceholders objectAtIndex:indexPath.row];

	cell.textLabel.text = placeholder.name;
	cell.UIplaceholder = placeholder;

    return cell;
}

-(BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	SPTests *test = [self.tests objectAtIndex:section];
	NSString *name = NSStringFromClass([test class]);

	// Extract words.
	NSMutableString *mutableName = [name mutableCopy];
	NSMutableArray *words = [NSMutableArray array];

	if ([mutableName hasPrefix:@"SP"])
		[mutableName replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];

	while (mutableName.length > 0) {
		NSRange nextCapitalRange = [mutableName rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]
																options:0
																  range:NSMakeRange(1, mutableName.length - 1)];

		NSRange wordRange;
		if (nextCapitalRange.location == NSNotFound)
			wordRange = NSMakeRange(0, mutableName.length);
		else
			wordRange = NSMakeRange(0, nextCapitalRange.location);

		[words addObject:[mutableName substringWithRange:wordRange]];
		[mutableName replaceCharactersInRange:wordRange withString:@""];
	}

	return [words componentsJoinedByString:@" "];
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

@end
