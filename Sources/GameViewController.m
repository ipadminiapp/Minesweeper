#import "GameViewController.h"
#import "MinesweeperModel.h"
#import "MSTile.h"

typedef struct { int r, c, m; } MSPreset;
static MSPreset kPresets[3] = { {9, 9, 10}, {16, 16, 40}, {16, 30, 99} };

@interface GameViewController ()
@property (nonatomic, strong) MinesweeperModel *model;
@property (nonatomic, assign) int curPreset;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<MSTile *> *> *tiles;
@property (nonatomic, strong) UIView *boardView;
@property (nonatomic, strong) UISegmentedControl *diff;
@property (nonatomic, strong) UILabel *mineLabel;
@property (nonatomic, strong) UILabel *timerLabel;
@property (nonatomic, strong) UIButton *faceButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *hud;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) int seconds;
@property (nonatomic, assign) BOOL gameEnded;
@end

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1];
    _curPreset = 1;
    _tiles = [NSMutableArray array];
    [self setupUI];
    [self startNewGame];
}

#pragma mark - UI

- (void)setupUI {
    self.diff = [[UISegmentedControl alloc] initWithItems:@[@"Beginner", @"Intermediate", @"Expert"]];
    self.diff.selectedSegmentIndex = _curPreset;
    [self.diff addTarget:self action:@selector(onDiffChange) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.diff];

    self.hud = [[UIView alloc] init];
    self.hud.backgroundColor = [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1];
    self.hud.layer.cornerRadius = 12;
    [self.view addSubview:self.hud];

    self.mineLabel = [self makeCounter];
    self.timerLabel = [self makeCounter];
    self.timerLabel.textColor = [UIColor colorWithRed:0.19 green:0.82 blue:0.35 alpha:1];
    [self.hud addSubview:self.mineLabel];
    [self.hud addSubview:self.timerLabel];

    self.faceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.faceButton setTitle:@"🙂" forState:UIControlStateNormal];
    self.faceButton.titleLabel.font = [UIFont systemFontOfSize:28];
    [self.faceButton addTarget:self action:@selector(onFace) forControlEvents:UIControlEventTouchUpInside];
    [self.hud addSubview:self.faceButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.63 alpha:1];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];

    self.boardView = [[UIView alloc] init];
    [self.view addSubview:self.boardView];
}

// Manual version check (avoids @available, which links __isOSVersionAtLeast
// that is absent from this toolchain's runtime). iPad Mini 4 is A8 (arm64).
static BOOL MSIsIOS11OrLater(void) {
    NSInteger major = 0;
    NSString *v = [[UIDevice currentDevice] systemVersion];
    NSArray<NSString *> *parts = [v componentsSeparatedByString:@"."];
    if (parts.count > 0) major = [parts[0] integerValue];
    return major >= 11;
}

- (UILabel *)makeCounter {
    UILabel *l = [[UILabel alloc] init];
    l.backgroundColor = [UIColor blackColor];
    l.textColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1];
    // monospacedDigitSystemFontOfSize:weight: is available from iOS 9.0,
    // which is our deployment target, so no runtime guard is needed.
    l.font = [UIFont monospacedDigitSystemFontOfSize:22 weight:UIFontWeightBold];
    l.text = @"000";
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 6;
    l.clipsToBounds = YES;
    return l;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat top = 0, bottom = 0;
    if (MSIsIOS11OrLater()) {
        top = self.view.safeAreaInsets.top;
        bottom = self.view.safeAreaInsets.bottom;
    } else {
        top = self.topLayoutGuide.length;
    }
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat y = top + 8;
    self.diff.frame = CGRectMake(10, y, w - 20, 32);
    y += 40;
    self.hud.frame = CGRectMake(10, y, w - 20, 56);
    CGFloat hw = self.hud.bounds.size.width;
    self.mineLabel.frame = CGRectMake(12, 8, 84, 40);
    self.faceButton.frame = CGRectMake(hw / 2 - 26, 4, 52, 48);
    self.timerLabel.frame = CGRectMake(hw - 96, 8, 84, 40);
    y += 64;
    self.statusLabel.frame = CGRectMake(10, y, w - 20, 18);
    y += 24;
    self.boardView.frame = CGRectMake(0, y, w, h - y - bottom - 8);
    [self layoutTiles];
}

#pragma mark - Game lifecycle

- (void)startNewGame {
    [self stopTimer];
    _seconds = 0;
    self.timerLabel.text = @"000";
    _gameEnded = NO;
    MSPreset p = kPresets[_curPreset];
    self.model = [[MinesweeperModel alloc] initWithRows:p.r cols:p.c mines:p.m];
    self.model.firstClick = YES;
    [self.faceButton setTitle:@"🙂" forState:UIControlStateNormal];
    self.statusLabel.text = @"Tap to reveal · Long-press to flag";
    [self buildTiles];
    [self refreshTiles];   // render the covered board immediately
    [self updateCounters];
    // Size/position the freshly built tiles. On first launch the system layout
    // pass handles this, but after a reset/win/loss there is no layout pass,
    // so without this the new tiles keep a zero frame and the board is invisible.
    if (self.boardView.bounds.size.width > 0 && self.boardView.bounds.size.height > 0)
        [self layoutTiles];
}

- (void)buildTiles {
    for (UIView *v in self.boardView.subviews) [v removeFromSuperview];
    [self.tiles removeAllObjects];
    MSPreset p = kPresets[_curPreset];
    for (int r = 0; r < p.r; r++) {
        NSMutableArray *row = [NSMutableArray array];
        for (int c = 0; c < p.c; c++) {
            MSTile *t = [[MSTile alloc] init];
            t.row = r; t.col = c;
            t.layer.cornerRadius = 4;
            t.clipsToBounds = YES;
            [t setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [t addTarget:self action:@selector(onTileTap:) forControlEvents:UIControlEventTouchUpInside];
            UILongPressGestureRecognizer *lp =
                [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
            lp.minimumPressDuration = 0.4;
            lp.cancelsTouchesInView = NO;   // let the release also reach the button so we can swallow it
            [t addGestureRecognizer:lp];
            // Visible covered-tile style so the board shows immediately
            // (refreshTiles only runs after a tap otherwise).
            t.backgroundColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.37 alpha:1];
            t.layer.borderColor = [UIColor colorWithRed:0.52 green:0.52 blue:0.55 alpha:1].CGColor;
            t.layer.borderWidth = 1.0;
            [self.boardView addSubview:t];
            [row addObject:t];
        }
        [self.tiles addObject:row];
    }
}

- (void)layoutTiles {
    if (self.tiles.count == 0) return;
    NSInteger rows = self.tiles.count;
    NSInteger cols = self.tiles[0].count;
    CGFloat gap = 2;
    CGFloat bw = self.boardView.bounds.size.width;
    CGFloat bh = self.boardView.bounds.size.height;
    CGFloat tile = (bw - (cols - 1) * gap) / cols;
    CGFloat tileH = (bh - (rows - 1) * gap) / rows;
    tile = MIN(tile, tileH);
    tile = MIN(tile, 46);
    tile = MAX(tile, 14);
    CGFloat boardW = cols * tile + (cols - 1) * gap;
    CGFloat boardH = rows * tile + (rows - 1) * gap;
    CGFloat ox = (bw - boardW) / 2;
    CGFloat oy = (bh - boardH) / 2;
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++) {
            MSTile *t = self.tiles[r][c];
            t.frame = CGRectMake(ox + c * (tile + gap), oy + r * (tile + gap), tile, tile);
            t.titleLabel.font = [UIFont boldSystemFontOfSize:tile * 0.5];
        }
}

#pragma mark - Interaction

- (void)onTileTap:(MSTile *)tile {
    if (tile.longPressed) { tile.longPressed = NO; return; }
    if (_gameEnded) return;
    int r = (int)tile.row, c = (int)tile.col;
    MSCell *cell = [self.model cellAtR:r c:c];
    if (self.model.firstClick) {
        [self.model placeMinesAvoidingR:r c:c];
        self.model.firstClick = NO;
        [self startTimer];
    }
    if (cell.revealed) {
        BOOL hit = [self.model chordR:r c:c];
        [self refreshTiles];
        if (hit) { [self loseGame]; return; }
        if ([self.model isWin]) [self winGame];
        return;
    }
    if (cell.flagged) return;
    BOOL hit = [self.model revealR:r c:c];
    [self refreshTiles];
    if (hit) { [self loseGame]; return; }
    if ([self.model isWin]) [self winGame];
}

- (void)onLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    MSTile *tile = (MSTile *)g.view;
    if (_gameEnded) return;
    MSCell *cell = [self.model cellAtR:(int)tile.row c:(int)tile.col];
    if (cell.revealed) { tile.longPressed = YES; return; }  // swallow the release so it won't chord
    [self.model toggleFlagR:(int)tile.row c:(int)tile.col];
    tile.longPressed = YES;
    [self refreshTiles];
}

- (void)refreshTiles {
    for (int r = 0; r < self.tiles.count; r++) {
        for (int c = 0; c < self.tiles[r].count; c++) {
            MSTile *t = self.tiles[r][c];
            MSCell *cell = [self.model cellAtR:r c:c];
            [t setTitle:@"" forState:UIControlStateNormal];
            [t setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            t.backgroundColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.37 alpha:1];
            t.layer.borderColor = [UIColor colorWithRed:0.52 green:0.52 blue:0.55 alpha:1].CGColor;
            t.layer.borderWidth = 1.0;
            if (cell.revealed) {
                t.backgroundColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.24 alpha:1];
                if (cell.mine) {
                    [t setTitle:@"💣" forState:UIControlStateNormal];
                    t.backgroundColor = [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1];
                } else if (cell.adj > 0) {
                    [t setTitle:[NSString stringWithFormat:@"%d", cell.adj] forState:UIControlStateNormal];
                    [t setTitleColor:[self colorForN:cell.adj] forState:UIControlStateNormal];
                }
            } else if (cell.flagged) {
                [t setTitle:@"🚩" forState:UIControlStateNormal];
            }
        }
    }
    [self updateCounters];
}

- (UIColor *)colorForN:(int)n {
    switch (n) {
        case 1: return [UIColor colorWithRed:0.04 green:0.52 blue:1.0 alpha:1];
        case 2: return [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1];
        case 3: return [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1];
        case 4: return [UIColor colorWithRed:0.75 green:0.35 blue:0.95 alpha:1];
        case 5: return [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1];
        case 6: return [UIColor colorWithRed:0.39 green:0.82 blue:1.0 alpha:1];
        case 7: return [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1];
        default: return [UIColor colorWithRed:0.88 green:0.88 blue:0.92 alpha:1];
    }
}

- (void)updateCounters {
    int left = self.model.mines - self.model.flagsUsed;
    self.mineLabel.text = [self pad3:left];
    self.timerLabel.text = [self pad3:self.seconds];
}

- (NSString *)pad3:(int)n {
    int v = MAX(-99, MIN(999, n));
    return [NSString stringWithFormat:@"%03d", v];
}

#pragma mark - Timer

- (void)startTimer {
    [self stopTimer];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(tick)
                                                userInfo:nil
                                                 repeats:YES];
}
- (void)stopTimer { [self.timer invalidate]; self.timer = nil; }
- (void)tick {
    self.seconds++;
    self.timerLabel.text = [self pad3:self.seconds];
    if (self.seconds >= 999) [self stopTimer];
}

#pragma mark - End states

- (void)loseGame {
    _gameEnded = YES;
    [self stopTimer];
    [self.faceButton setTitle:@"😵" forState:UIControlStateNormal];
    self.statusLabel.text = @"Boom! Tap the face to retry.";
    for (int r = 0; r < self.tiles.count; r++)
        for (int c = 0; c < self.tiles[r].count; c++) {
            MSTile *t = self.tiles[r][c];
            MSCell *cell = [self.model cellAtR:r c:c];
            if (cell.mine && !cell.flagged) {
                [t setTitle:@"💣" forState:UIControlStateNormal];
                t.backgroundColor = [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1];
            } else if (cell.flagged && !cell.mine) {
                [t setTitle:@"❌" forState:UIControlStateNormal];
                t.backgroundColor = [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1];
            }
        }
}

- (void)winGame {
    _gameEnded = YES;
    [self stopTimer];
    [self.faceButton setTitle:@"😎" forState:UIControlStateNormal];
    self.statusLabel.text = [NSString stringWithFormat:@"You won! %@s", [self pad3:self.seconds]];
    for (int r = 0; r < self.tiles.count; r++)
        for (int c = 0; c < self.tiles[r].count; c++) {
            MSCell *cell = [self.model cellAtR:r c:c];
            if (cell.mine && !cell.flagged) cell.flagged = YES;
        }
    [self refreshTiles];
}

#pragma mark - Controls

- (void)onFace { [self startNewGame]; }
- (void)onDiffChange {
    _curPreset = (int)self.diff.selectedSegmentIndex;
    [self startNewGame];
}

@end
