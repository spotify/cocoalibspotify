//
//  TestProgressCell.m
//  CocoaLibSpotify iOS Library
//
//  Created by Daniel Kennett on 02/10/2012.
//
//

#import "TestProgressCell.h"

@implementation TestProgressCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
		[self addObserver:self forKeyPath:@"UIplaceholder.state" options:0 context:nil];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@synthesize UIplaceholder;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"UIplaceholder.state"]) {

		if (self.UIplaceholder.state == kTestStateWaiting) {
			self.accessoryView = nil;

		} else if (self.UIplaceholder.state == kTestStateRunning) {
			UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[indicator startAnimating];
			self.accessoryView = indicator;

		} else if (self.UIplaceholder.state == kTestStatePassed) {
			self.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Pass"]];
			
		} else if (self.UIplaceholder.state == kTestStateFailed) {
			self.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Fail"]];
		}

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)dealloc {
	[self removeObserver:self forKeyPath:@"UIplaceholder.state"];
}

@end
