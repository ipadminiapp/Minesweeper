#import <Foundation/Foundation.h>

@interface MSCell : NSObject
@property (nonatomic, assign) BOOL mine;
@property (nonatomic, assign) BOOL revealed;
@property (nonatomic, assign) BOOL flagged;
@property (nonatomic, assign) int adj;
@end

@interface MinesweeperModel : NSObject
@property (nonatomic, assign, readonly) int rows;
@property (nonatomic, assign, readonly) int cols;
@property (nonatomic, assign, readonly) int mines;
@property (nonatomic, assign) BOOL firstClick;
@property (nonatomic, assign, readonly) int flagsUsed;
@property (nonatomic, assign, readonly) int revealedCount;

- (instancetype)initWithRows:(int)rows cols:(int)cols mines:(int)mines;
- (MSCell *)cellAtR:(int)r c:(int)c;
- (void)placeMinesAvoidingR:(int)r c:(int)c;
- (BOOL)revealR:(int)r c:(int)c;        // YES if a mine was hit
- (void)toggleFlagR:(int)r c:(int)c;
- (BOOL)chordR:(int)r c:(int)c;         // YES if a mine was hit
- (BOOL)isWin;
@end
