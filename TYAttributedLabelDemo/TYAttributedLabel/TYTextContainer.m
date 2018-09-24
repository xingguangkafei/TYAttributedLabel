//
//  TYTextContainer.m
//  TYAttributedLabelDemo
//
//  Created by tanyang on 15/6/4.
//  Copyright (c) 2015年 tanyang. All rights reserved.
//

#import "TYTextContainer.h"

#define kTextColor       [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1]
#define kLinkColor       [UIColor colorWithRed:0/255.0 green:91/255.0 blue:255/255.0 alpha:1]
/*
 NSMutableAttributedString *attriText = [[NSMutableAttributedString alloc] initWithString:nil];
 NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
 [paragraphStyle setLineSpacing:5];
 [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
 [attriText addAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11.0],NSForegroundColorAttributeName:[UIColor redColor],NSParagraphStyleAttributeName:@0} range:NSMakeRange(0, 0)];
 
 NSAttributedString 这个类定义在Foundation框架里，却在UIKit框架里定义了NSFontAttributeName这种属性... swift用起来就友好很多了
 
 Foundation --> 定义 NSAttributedString
 UIKit --> 类扩展 NSAttributedString
 CoreText --> 定义 CGStringAttribute
 */
// this code quote TTTAttributedLabel
static inline CGSize CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints(CTFramesetterRef framesetter, NSAttributedString *attributedString, CGSize size, NSUInteger numberOfLines) {
    // 如果只有一行的话呢，这个length就是文字的长度
    CFRange rangeToSize = CFRangeMake(0, (CFIndex)[attributedString length]);
    CGSize constraints = CGSizeMake(size.width, MAXFLOAT);
    
    if (numberOfLines > 0) {
        // If the line count of the label more than 1, limit the range to size to the number of lines that have been set
        // 创建一个可变路径
        CGMutablePathRef path = CGPathCreateMutable();
        // 再在路径上画出矩形
        CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, constraints.width, MAXFLOAT));
        // 计算出 CoreText 的实际大小
        CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
        // 获取全部文字所需要的行数
        CFArrayRef lines = CTFrameGetLines(frame);
        // 如果全部行数大于0，至少有一行的时候
        if (CFArrayGetCount(lines) > 0) {
            // 最后可见的一行 = 设置的行数和实际行数的最小值
            NSInteger lastVisibleLineIndex = MIN((CFIndex)numberOfLines, CFArrayGetCount(lines)) - 1;
            // 最后一行文字数据
            CTLineRef lastVisibleLine = CFArrayGetValueAtIndex(lines, lastVisibleLineIndex);
            // 最后一行文字的 长度和所在的位置
            CFRange rangeToLayout = CTLineGetStringRange(lastVisibleLine);
            // 根据随后一行的长度和所在的位置，计算最终的大小
            rangeToSize = CFRangeMake(0, rangeToLayout.location + rangeToLayout.length);
        }
        
        CFRelease(frame);
        CFRelease(path);
    }
    // CoreText接口计算最终文字绘制出来的size大小
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, rangeToSize, NULL, constraints, NULL);
    
    return CGSizeMake(ceil(suggestedSize.width), ceil(suggestedSize.height));
}

@interface TYTextContainer()
@property (nonatomic, strong) NSMutableArray    *textStorageArray;  // run数组
@property (nonatomic, strong) NSArray *textStorages; // run array copy

@property (nonatomic, strong) NSDictionary  *drawRectDictionary;
@property (nonatomic, strong) NSDictionary  *runRectDictionary;  // runRect字典
@property (nonatomic, strong) NSDictionary  *linkRectDictionary; // linkRect字典

@property (nonatomic, assign) NSInteger         replaceStringNum;   // 图片替换字符数
@property (nonatomic, strong) NSMutableAttributedString *attString;
@property (nonatomic, assign) CTFrameRef  frameRef;
@property (nonatomic, assign) CGFloat     textHeight;
@property (nonatomic, assign) CGFloat     textWidth;

@end

@implementation TYTextContainer

- (instancetype)init {
    if (self = [super init]) {
        [self setupProperty];
    }
    return self;
}

#pragma mark - getter

- (NSMutableArray *)textStorageArray {
    if (_textStorageArray == nil) {
        _textStorageArray = [NSMutableArray array];
    }
    return _textStorageArray;
}

- (NSString *)text{
    return _attString.string;
}

- (NSAttributedString *)attributedText {
    return [_attString copy];
}

- (NSAttributedString *)createAttributedString {
    [self addTextStoragesWithAtrributedString:_attString];
    if (_attString == nil) {
        _attString = [[NSMutableAttributedString alloc]init];
    }
    return [_attString copy];
}
// 设置一些默认属性
#pragma mark - setter
- (void)setupProperty
{
    _font = [UIFont systemFontOfSize:15];
    _characterSpacing = 1;
    _linesSpacing = 2;
    _paragraphSpacing = 0;
    _textAlignment = kCTLeftTextAlignment;
    _lineBreakMode = kCTLineBreakByCharWrapping;
    _textColor = kTextColor;
    _linkColor = kLinkColor;
    _replaceStringNum = 0;
}

- (void)resetAllAttributed
{
    [self resetRectDictionary];
    _textStorageArray = nil;
    _textStorages = nil;
    _replaceStringNum = 0;
}

- (void)resetRectDictionary
{
    _drawRectDictionary = nil;
    _linkRectDictionary = nil;
    _runRectDictionary = nil;
}

- (void)resetFrameRef
{
    if (_frameRef) {
        CFRelease(_frameRef);
        _frameRef = nil;
    }
    _textHeight = 0;
}

- (void)setText:(NSString *)text
{
    _attString = [self createTextAttibuteStringWithText:text];
    [self resetAllAttributed];
    [self resetFrameRef];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    if (attributedText == nil) {
        _attString = [[NSMutableAttributedString alloc]init];
    }else if ([attributedText isKindOfClass:[NSMutableAttributedString class]]) {
        _attString = (NSMutableAttributedString *)attributedText;
    }else {
        _attString = [[NSMutableAttributedString alloc]initWithAttributedString:attributedText];
    }
    [self resetAllAttributed];
    [self resetFrameRef];
}

- (void)setTextColor:(UIColor *)textColor
{
    if (textColor && _textColor != textColor){
        _textColor = textColor;
        
        [_attString addAttributeTextColor:textColor];
        [self resetFrameRef];
    }
}

- (void)setFont:(UIFont *)font
{
    if (font && _font != font){
        _font = font;
        
        [_attString addAttributeFont:font];
        [self resetFrameRef];
    }
}

- (void)setStrokeWidth:(unichar)strokeWidth
{
    if (_strokeWidth != strokeWidth) {
        _strokeWidth = strokeWidth;
        [_attString addAttributeStrokeWidth:strokeWidth strokeColor:_strokeColor];
        [self resetFrameRef];
    }
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    if (strokeColor && _strokeColor != strokeColor) {
        _strokeColor = strokeColor;
        [_attString addAttributeStrokeWidth:_strokeWidth strokeColor:strokeColor];
        [self resetFrameRef];
    }
}

- (void)setCharacterSpacing:(unichar)characterSpacing
{
    if (_characterSpacing != characterSpacing) {
        _characterSpacing = characterSpacing;
        
        [_attString addAttributeCharacterSpacing:characterSpacing];
        [self resetFrameRef];
    }
}

- (void)setLinesSpacing:(CGFloat)linesSpacing
{
    if (_linesSpacing != linesSpacing) {
        _linesSpacing = linesSpacing;
        
        [self addAttributeAlignmentStyle:_textAlignment lineSpaceStyle:linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:_lineBreakMode];
        [self resetFrameRef];
    }
}

- (void)setParagraphSpacing:(CGFloat)paragraphSpacing
{
    if (_paragraphSpacing != paragraphSpacing) {
        _paragraphSpacing = paragraphSpacing;
        [self addAttributeAlignmentStyle:_textAlignment lineSpaceStyle:_linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:_lineBreakMode];
        [self resetFrameRef];
    }
}

- (void)setTextAlignment:(CTTextAlignment)textAlignment
{
    if (_textAlignment != textAlignment) {
        _textAlignment = textAlignment;
        
        [self addAttributeAlignmentStyle:textAlignment lineSpaceStyle:_linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:_lineBreakMode];
        [self resetFrameRef];
    }
}

- (void)setLineBreakMode:(CTLineBreakMode)lineBreakMode
{
    if (_lineBreakMode != lineBreakMode) {
        _lineBreakMode = lineBreakMode;
        
        [self addAttributeAlignmentStyle:_textAlignment lineSpaceStyle:_linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:_lineBreakMode];
        [self resetFrameRef];

    }
}

#pragma mark - create text attibuteString
- (NSMutableAttributedString *)createTextAttibuteStringWithText:(NSString *)text
{
    if (text.length <= 0) {
        return [[NSMutableAttributedString alloc]init];
    }
    // 创建属性文本
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc]initWithString:text];
    
    // 添加文本颜色 字体属性
    [self addTextColorAndFontWithAtrributedString:attString];
    
    // 添加文本段落样式
    [self addTextParaphStyleWithAtrributedString:attString];
    
    return attString;
}

// 添加文本颜色 字体属性
- (void)addTextColorAndFontWithAtrributedString:(NSMutableAttributedString *)attString
{
    // 添加文本字体
    [attString addAttributeFont:_font];
    
    // 添加文本颜色
    [attString addAttributeTextColor:_textColor];
    
    // 添加空心字体
    if (_strokeWidth > 0) {
        [attString addAttributeStrokeWidth:_strokeWidth strokeColor:_strokeColor];
    }
    
}

// 添加文本段落样式
- (void)addTextParaphStyleWithAtrributedString:(NSMutableAttributedString *)attString
{
    // 字体间距
    if (_characterSpacing)
    {
        [attString addAttributeCharacterSpacing:_characterSpacing];
    }
    
    // 添加文本段落样式
    [self addAttributeAlignmentStyle:_textAlignment lineSpaceStyle:_linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:_lineBreakMode];
}

- (void)addAttributeAlignmentStyle:(CTTextAlignment)textAlignment
                    lineSpaceStyle:(CGFloat)linesSpacing
               paragraphSpaceStyle:(CGFloat)paragraphSpacing
                    lineBreakStyle:(CTLineBreakMode)lineBreakMode
{
    if (lineBreakMode == kCTLineBreakByTruncatingTail)
    {
        lineBreakMode = _numberOfLines == 1 ? kCTLineBreakByCharWrapping : kCTLineBreakByWordWrapping;
    }
    [_attString addAttributeAlignmentStyle:_textAlignment lineSpaceStyle:_linesSpacing paragraphSpaceStyle:_paragraphSpacing lineBreakStyle:lineBreakMode];
}

#pragma mark -  add text storage atrributed
- (void)addTextStoragesWithAtrributedString:(NSMutableAttributedString *)attString
{
    if (attString && _textStorageArray.count > 0) {
        
        // 排序range
        // 这个排序函数式有问题的
        [self sortTextStorageArray:_textStorageArray];
        
        for (id<TYTextStorageProtocol> textStorage in _textStorageArray) {
            
            // 修正图片替换字符来的误差
            if ([textStorage conformsToProtocol:@protocol(TYDrawStorageProtocol) ]) {
                continue;
            }
            
            if ([textStorage conformsToProtocol:@protocol(TYLinkStorageProtocol)]) {
                if (!((id<TYLinkStorageProtocol>)textStorage).textColor) {
                    ((id<TYLinkStorageProtocol>)textStorage).textColor = _linkColor;
                }
            }
            
            // 验证范围
            if (NSMaxRange(textStorage.range) <= attString.length) {
                [textStorage addTextStorageWithAttributedString:attString];
            }
            
        }
        
        for (id<TYTextStorageProtocol> textStorage in _textStorageArray) {
            textStorage.realRange = NSMakeRange(textStorage.range.location-_replaceStringNum, textStorage.range.length);
            if ([textStorage conformsToProtocol:@protocol(TYDrawStorageProtocol)]) {
                id<TYDrawStorageProtocol> drawStorage = (id<TYDrawStorageProtocol>)textStorage;
                NSInteger currentLenght = attString.length;
                [drawStorage setTextfontAscent:_font.ascender descent:_font.descender];
                [drawStorage currentReplacedStringNum:_replaceStringNum];
                [drawStorage addTextStorageWithAttributedString:attString];
                _replaceStringNum += currentLenght - attString.length;
            }
        }
        _textStorages = [_textStorageArray copy];
        [_textStorageArray removeAllObjects];
    }
}

/*
 storage: n. 存储；仓库；贮藏所
 
 排序 文本存储数组，数组里的每个元素都遵循TYTextStorageProtocol协议
 按照元素的 range属性的location来大小来排序，如果location小的话，就升序排列
 
 这个排序的结果跟没有排序是一样的，作者写错了 ？
 */
- (void)sortTextStorageArray:(NSMutableArray *)textStorageArray
{
    [textStorageArray sortUsingComparator:^NSComparisonResult(id<TYTextStorageProtocol> obj1, id<TYTextStorageProtocol> obj2) {
        if (obj1.range.location < obj2.range.location) {
            return NSOrderedAscending;
        } else if (obj1.range.location > obj2.range.location){
            return NSOrderedDescending;
        }else {
            return obj1.range.length > obj2.range.length ? NSOrderedAscending:NSOrderedDescending;
        }
    }];
}
/* CTRunStatus
 kCTRunStatusNoStatus = 0,  没有状态
 kCTRunStatusRightToLeft = (1 << 0), 跑道从左往右
 kCTRunStatusNonMonotonic = (1 << 1), 跑道非线性的，例如可能是指数级的
 kCTRunStatusHasNonIdentityMatrix = (1 << 2) 跑道需要指定一个矩阵，来指定每一个run
 */
- (void)saveTextStorageRectWithFrame:(CTFrameRef)frame
{
    if (!frame) {
        return;
    }
    // 获取每行
    CFArrayRef lines = CTFrameGetLines(frame);
    // 准备获取每一行的位置
    CGPoint lineOrigins[CFArrayGetCount(lines)];
    // 准备获取每一行的位置和大小
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOrigins);
    CGFloat viewWidth = _textWidth;
    // 最终行数取 能显示出来的实际行数
    NSInteger numberOfLines = _numberOfLines > 0 ? MIN(_numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    
    NSMutableDictionary *runRectDictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *linkRectDictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *drawRectDictionary = [NSMutableDictionary dictionary];
    // 获取每行有多少run
    for (int i = 0; i < numberOfLines; i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;
        // 获取每一行的 上高下高，顶高
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        // 获取每一行的run数组
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        // 获得每行的run
        for (int j = 0; j < CFArrayGetCount(runs); j++) {
            CGFloat runAscent;
            CGFloat runDescent;
            CGPoint lineOrigin = lineOrigins[i];
            // 获取到最小的绘制单位：run
            CTRunRef run = CFArrayGetValueAtIndex(runs, j);
            // run的属性字典
            // 获取到绘制的时候，用kTYTextRunAttributedName作为key添加到attString的storage
            NSDictionary* attributes = (NSDictionary*)CTRunGetAttributes(run);
            id<TYTextStorageProtocol> textStorage = [attributes objectForKey:kTYTextRunAttributedName];
            
            if (textStorage) {
                // 如果是有个storage，获取run的宽度；获取run的 上高和下高
                CGFloat runWidth  = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
                // 如果 文本有宽度，且，run的宽度大于文本宽度，那么就强制使用设置好的文本宽度
                if (viewWidth > 0 && runWidth > viewWidth) {
                    runWidth  = viewWidth;
                }
                /*
                 获取run的大小和位置；
                 位置x = 这一行的x + run的location
                 位置y = 这一行的y - run的下高
                 宽w = runWidth
                 宽h = run上高 + run下高
                 */
                CGRect runRect = CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runWidth, runAscent + runDescent);
                
                if ([textStorage conformsToProtocol:@protocol(TYDrawStorageProtocol)]) {
                    // 找出drawStorage添加runRect到DrawRect字典
                    [drawRectDictionary setObject:textStorage forKey:[NSValue valueWithCGRect:runRect]];
                } else if ([textStorage conformsToProtocol:@protocol(TYLinkStorageProtocol)]) {
                    // 找出linkStorage添加runRect到LinkRect字典
                    [linkRectDictionary setObject:textStorage forKey:[NSValue valueWithCGRect:runRect]];
                }
                // 所有storage类型都添加到RunRect字典
                [runRectDictionary setObject:textStorage forKey:[NSValue valueWithCGRect:runRect]];
            }
        }
    }
    
    if (drawRectDictionary.count > 0) {
        _drawRectDictionary = [drawRectDictionary copy];
    }else {
        _drawRectDictionary = nil;
    }
    
    if (runRectDictionary.count > 0) {
        // 添加响应点击rect
        [self addRunRectDictionary:[runRectDictionary copy]];
    }
    
    if (linkRectDictionary.count > 0) {
        _linkRectDictionary = [linkRectDictionary copy];
    }else {
        _linkRectDictionary = nil;
    }
}

// 添加响应点击rect
- (void)addRunRectDictionary:(NSDictionary *)runRectDictionary
{
    if (runRectDictionary.count < _runRectDictionary.count) {
        NSMutableArray *drawStorageArray = [[_runRectDictionary allValues]mutableCopy];
        // 剔除已经画出来的
        [drawStorageArray removeObjectsInArray:[runRectDictionary allValues]];
        
        // 遍历不会画出来的
        for (id<TYTextStorageProtocol>drawStorage in drawStorageArray) {
            if ([drawStorage conformsToProtocol:@protocol(TYViewStorageProtocol)]) {
                [(id<TYViewStorageProtocol>)drawStorage didNotDrawRun];
            }
        }
    }
    _runRectDictionary = runRectDictionary;
}
// 这个函数是算了至少两边的，一次是计算View的size的时候，一次是draw到rect的时候
- (CGSize)getSuggestedSizeWithFramesetter:(CTFramesetterRef)framesetter width:(CGFloat)width
{
    if (_attString == nil || width <= 0) {
        return CGSizeZero;
    }
    
    if (_textHeight > 0) {
        return CGSizeMake(_textWidth > 0 ? _textWidth : width, _textHeight);
    }
    
    // 是否需要更新frame
    if (framesetter == nil) {
        // 如果没有 CoreText frameSetter, 那么就创建一个
        framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)[self createAttributedString]);
    }else {
        CFRetain(framesetter);
    }
    
    // 获得建议的size
    // 这里主要是为了把外界代码设置的文字行数那个值用上，才又包装了一个方法
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints(framesetter, _attString, CGSizeMake(width,MAXFLOAT), _numberOfLines);
    
    CFRelease(framesetter);

    return CGSizeMake(_isWidthToFit ? suggestedSize.width : width, suggestedSize.height+1);
}
- (CGFloat)getHeightWithFramesetter:(CTFramesetterRef)framesetter width:(CGFloat)width
{
    return [self getSuggestedSizeWithFramesetter:framesetter width:width].height;
}

-  (CTFrameRef)createFrameRefWithFramesetter:(CTFramesetterRef)framesetter textSize:(CGSize)textSize
{
    // 这里你需要创建一个用于绘制文本的路径区域,通过 self.bounds 使用整个视图矩形区域创建 CGPath 引用。
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat textHeight = [self getHeightWithFramesetter:framesetter width:textSize.width];
    CGPathAddRect(path, NULL, CGRectMake(0, 0, textSize.width, MAX(textHeight, textSize.height)));
    
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, [_attString length]), path, NULL);
    CFRelease(path);
    return frameRef;
}

- (instancetype)createTextContainerWithTextWidth:(CGFloat)textWidth
{
    return [self createTextContainerWithContentSize:CGSizeMake(textWidth, 0)];
}

- (instancetype)createTextContainerWithContentSize:(CGSize)contentSize
{
    if (_frameRef) {
        return self;
    }
    NSAttributedString *attStr = [self createAttributedString];
    // 创建CTFramesetter
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attStr);
    
    // 获得建议的size
    CGSize size = [self getSuggestedSizeWithFramesetter:framesetter width:contentSize.width];
    _textWidth = size.width;
    _textHeight = size.height;
    
    // 创建CTFrameRef
    _frameRef = [self createFrameRefWithFramesetter:framesetter textSize:CGSizeMake(_textWidth, contentSize.height > 0 ? contentSize.height : _textHeight)];
    
    // 释放内存
    CFRelease(framesetter);
    
    // 保存run rect
    [self saveTextStorageRectWithFrame:_frameRef];
    
    return self;
}

#pragma mark - enumerate runRect

- (BOOL)existRunRectDictionary
{
    return _runRectDictionary.count != 0;
}

- (BOOL)existLinkRectDictionary
{
    return _linkRectDictionary.count != 0;
}

- (BOOL)existDrawRectDictionary
{
    return _drawRectDictionary.count != 0;
}

- (void)enumerateDrawRectDictionaryUsingBlock:(void (^)(id<TYDrawStorageProtocol> drawStorage, CGRect rect))block
{
    [_drawRectDictionary enumerateKeysAndObjectsUsingBlock:^(NSValue *rectValue, id<TYDrawStorageProtocol> drawStorage, BOOL * stop) {
        if (block) {
            block(drawStorage,[rectValue CGRectValue]);
        }
    }];
}

- (BOOL)enumerateRunRectContainPoint:(CGPoint)point viewHeight:(CGFloat)viewHeight successBlock:(void (^)(id<TYTextStorageProtocol> textStorage))successBlock
{
    return [self enumerateRunRect:_runRectDictionary ContainPoint:point viewHeight:viewHeight successBlock:successBlock];
}

- (BOOL)enumerateLinkRectContainPoint:(CGPoint)point viewHeight:(CGFloat)viewHeight successBlock:(void (^)(id<TYLinkStorageProtocol> textStorage))successBlock
{
    return [self enumerateRunRect:_linkRectDictionary ContainPoint:point viewHeight:viewHeight successBlock:successBlock];
}

- (BOOL)enumerateRunRect:(NSDictionary *)runRectDic ContainPoint:(CGPoint)point viewHeight:(CGFloat)viewHeight successBlock:(void (^)(id<TYTextStorageProtocol> textStorage))successBlock
{
    if (runRectDic.count == 0) {
        return NO;
    }
    // CoreText context coordinates are the opposite to UIKit so we flip the bounds
    // 转换 CoreGraphic 和 UIKit的坐标系
    CGAffineTransform transform =  CGAffineTransformScale(CGAffineTransformMakeTranslation(0, viewHeight), 1.f, -1.f);
    
    __block BOOL find = NO;
    // 遍历run位置字典
    [runRectDic enumerateKeysAndObjectsUsingBlock:^(NSValue *keyRectValue, id<TYTextStorageProtocol> textStorage, BOOL *stop) {
        
        CGRect imgRect = [keyRectValue CGRectValue];
        CGRect rect = CGRectApplyAffineTransform(imgRect, transform);
        
        if ([textStorage conformsToProtocol:@protocol(TYDrawStorageProtocol) ]) {
            rect = UIEdgeInsetsInsetRect(rect,((id<TYDrawStorageProtocol>)textStorage).margin);
        }
        
        // point 是否在rect里
        if(CGRectContainsPoint(rect, point)){
            find = YES;
            *stop = YES;
            if (successBlock) {
                successBlock(textStorage);
            }
        }
    }];
    return find;
}

- (void)dealloc{
    [self resetFrameRef];
}

@end

#pragma mark - add textStorage
@implementation TYTextContainer (Add)

- (void)addTextStorage:(id<TYTextStorageProtocol>)textStorage
{
    if (textStorage) {
        [self.textStorageArray addObject:textStorage];
        [self resetFrameRef];
    }
}

- (void)addTextStorageArray:(NSArray *)textStorageArray
{
    if (textStorageArray) {
        for (id<TYTextStorageProtocol> textStorage in textStorageArray) {
            if ([textStorage conformsToProtocol:@protocol(TYTextStorageProtocol)]) {
                [self addTextStorage:textStorage];
            }
        }
    }
}
@end

#pragma mark - append textStorage
@implementation TYTextContainer (Append)

- (void)appendText:(NSString *)text
{
    // 添加文字的时候，创建一个 NSAttributedString
    NSAttributedString *attributedText = [self createTextAttibuteStringWithText:text];
    [self appendTextAttributedString:attributedText];
    // 重置 CoreText Frame属性
    [self resetFrameRef];
}
// 把传递进来的参数 添加到原来的 NSAttributedString 后面，调用 NSAttributedString 的接口 appendAttributedString
- (void)appendTextAttributedString:(NSAttributedString *)attributedText
{
    if (attributedText == nil) {
        return;
    }
    if (_attString == nil) {
        _attString = [[NSMutableAttributedString alloc]init];
    }
    
    if ([attributedText isKindOfClass:[NSMutableAttributedString class]]) {
        [self addTextParaphStyleWithAtrributedString:(NSMutableAttributedString *)attributedText];
    }
    
    [_attString appendAttributedString:attributedText];
    [self resetFrameRef];
}

- (void)appendTextStorage:(id<TYAppendTextStorageProtocol>)textStorage
{
    if (textStorage) {
        if ([textStorage conformsToProtocol:@protocol(TYDrawStorageProtocol)]) {
            [(id<TYDrawStorageProtocol>)textStorage setTextfontAscent:_font.ascender descent:_font.descender];
        } else if ([textStorage conformsToProtocol:@protocol(TYLinkStorageProtocol)]) {
            if (!((id<TYLinkStorageProtocol>)textStorage).textColor) {
                ((id<TYLinkStorageProtocol>)textStorage).textColor = _linkColor;
            }
        }
        
        NSAttributedString *attAppendString = [textStorage appendTextStorageAttributedString];
        // NSLog(@"attAppendString-%@-attAppendString",attAppendString.string);
        // 经过打印，还真是个空格，但是这个空格显示出来没有长度，因为xcode的log光标，要往左或者往右移一下才行
//        NSLog(@"attAppendString-%@-attAppendString",attAppendString);
//        NSLog(@"attAppendString-%lu-attAppendString",attAppendString.string.length);
        
        /*
         更新 Storage 的 realRange：新添加的这个storage 的 location 和 length，就分别是原来String的 尾部 和 storage的长度
         如果是文字storage 就是文字长度
         如果是图片storage 就是单位一长度
         */
        textStorage.realRange = NSMakeRange(_attString.length, attAppendString.length);
        // 把这个追加的storage的内容添加到原有的富文本尾部
        [self appendTextAttributedString:attAppendString];
        // 清空frame计算，为重绘做准备
        [self resetFrameRef];
    }
}

- (void)appendTextStorageArray:(NSArray *)textStorageArray
{
    if (textStorageArray) {
        for (id<TYAppendTextStorageProtocol> textStorage in textStorageArray) {
            if ([textStorage conformsToProtocol:@protocol(TYAppendTextStorageProtocol)]) {
                [self appendTextStorage:textStorage];
            }
        }
    }
}

@end
