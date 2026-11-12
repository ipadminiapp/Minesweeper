#import "MinesweeperModel.h"

@implementation MSCell
@end

@interface MinesweeperModel ()
@property (nonatomic, assign) int rows;
@property (nonatomic, assign) int cols;
@property (nonatomic, assign) int mines;
@property (nonatomic, assign) int flagsUsed;
@property (nonatomic, assign) int revealedCount;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<MSCell *> *> *grid;
@end

@implementation MinesweeperModel

- (instancetype)initWithRows:(int)rows cols:(int)cols mines:(int)mines {
    self = [super init];
    if (self) {
        _rows = rows; _cols = cols; _mines = mines;
        _firstClick = YES; _flagsUsed = 0; _revealedCount = 0;
        _grid = [NSMutableArray arrayWithCapacity:rows];
        for (int r = 0; r < rows; r++) {
            NSMutableArray *row = [NSMutableArray arrayWithCapacity:cols];
            for (int c = 0; c < cols; c++) [row addObject:[[MSCell alloc] init]];
            [_grid addObject:row];
        }
    }
    return self;
}

- (MSCell *)cellAtR:(int)r c:(int)c {
    if (r < 0 || c < 0 || r >= _rows || c >= _cols) return nil;
    return _grid[r][c];
}

- (void)placeMinesAvoidingR:(int)sr c:(int)sc {
    NSMutableSet *forbidden = [NSMutableSet set];
    for (int dr = -1; dr <= 1; dr++)
        for (int dc = -1; dc <= 1; dc++) {
            int r = sr + dr, c = sc + dc;
            if (r >= 0 && c >= 0 && r < _rows && c < _cols)
                [forbidden addObject:[NSString stringWithFormat:@"%d,%d", r, c]];
        }
    int placed = 0;
    while (placed < _mines) {
        int r = arc4random_uniform(_rows);
        int c = arc4random_uniform(_cols);
        if ([forbidden containsObject:[NSString stringWithFormat:@"%d,%d", r, c]]) continue;
        MSCell *cell = _grid[r][c];
        if (cell.mine) continue;
        cell.mine = YES;
        placed++;
    }
    for (int r = 0; r < _rows; r++)
        for (int c = 0; c < _cols; c++) {
            MSCell *cell = _grid[r][c];
            if (cell.mine) continue;
            int n = 0;
            for (int dr = -1; dr <= 1; dr++)
                for (int dc = -1; dc <= 1; dc++) {
                    if (dr == 0 && dc == 0) continue;
                    int rr = r + dr, cc = c + dc;
                    if (rr >= 0 && cc >= 0 && rr < _rows && cc < _cols && _grid[rr][cc].mine) n++;
                }
            cell.adj = n;
        }
}

- (BOOL)revealR:(int)r c:(int)c {
    if (r < 0 || c < 0 || r >= _rows || c >= _cols) return NO;
    MSCell *cell = _grid[r][c];
    if (cell.revealed || cell.flagged) return NO;
    cell.revealed = YES;
    _revealedCount++;
    if (cell.mine) return YES;
    if (cell.adj == 0) {
        for (int dr = -1; dr <= 1; dr++)
            for (int dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) continue;
                [self revealR:r + dr c:c + dc];
            }
    }
    return NO;
}

- (void)toggleFlagR:(int)r c:(int)c {
    MSCell *cell = [self cellAtR:r c:c];
    if (!cell || cell.revealed) return;
    cell.flagged = !cell.flagged;
    _flagsUsed += cell.flagged ? 1 : -1;
}

- (BOOL)chordR:(int)r c:(int)c {
    MSCell *cell = [self cellAtR:r c:c];
    if (!cell || !cell.revealed || cell.adj == 0) return NO;
    int flagged = 0;
    NSMutableArray *toReveal = [NSMutableArray array];
    for (int dr = -1; dr <= 1; dr++)
        for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            int rr = r + dr, cc = c + dc;
            MSCell *n = [self cellAtR:rr c:cc];
            if (!n) continue;
            if (n.flagged) flagged++;
            else if (!n.revealed) [toReveal addObject:@[@(rr), @(cc)]];
        }
    if (flagged != cell.adj) return NO;
    BOOL hit = NO;
    for (NSArray *p in toReveal) {
        if ([self revealR:[p[0] intValue] c:[p[1] intValue]]) hit = YES;
    }
    return hit;
}

- (BOOL)isWin {
    return _revealedCount == _rows * _cols - _mines;
}

@end
