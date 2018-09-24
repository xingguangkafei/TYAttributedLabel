//
//  TYAttributedLabel.m
//  TYAttributedLabelDemo
//
//  Created by tanyang on 15/4/8.
//  Copyright (c) 2015年 tanyang. All rights reserved.
//

#import "TYAttributedLabel.h"
#import <CoreText/CoreText.h>

#define kSelectAreaColor [UIColor colorWithRed:204/255.0 green:211/255.0 blue:236/255.0 alpha:1]
#define kHighLightLinkColor [UIColor colorWithRed:28/255.0 green:0/255.0 blue:213/255.0 alpha:1]

static NSString* const kEllipsesCharacter = @"\u2026";
NSString *const kTYTextRunAttributedName = @"TYTextRunAttributedName";

@interface TYTextContainer ()
@property (nonatomic, strong) NSMutableAttributedString *attString;
@property (nonatomic, assign,readonly) CTFrameRef  frameRef;

- (void)resetFrameRef;

- (void)resetRectDictionary;

- (BOOL)existRunRectDictionary;
- (BOOL)existLinkRectDictionary;
- (BOOL)existDrawRectDictionary;

- (void)enumerateDrawRectDictionaryUsingBlock:(void (^)(id<TYDrawStorageProtocol> drawStorage, CGRect rect))block;

- (BOOL)enumerateRunRectContainPoint:(CGPoint)point
                          viewHeight:(CGFloat)viewHeight
                        successBlock:(void (^)(id<TYTextStorageProtocol> textStorage))successBlock;

- (BOOL)enumerateLinkRectContainPoint:(CGPoint)point
                           viewHeight:(CGFloat)viewHeight
                         successBlock:(void (^)(id<TYLinkStorageProtocol> linkStorage))successBlock;

@end

@interface TYAttributedLabel ()<UIGestureRecognizerDelegate>
{
    struct {
        unsigned int textStorageClickedAtPoint :1;
        unsigned int textStorageLongPressedOnStateAtPoint :1;
    }_delegateFlags;
    // 这个结构体值，节省了hash表IMP遍历次数，简化了写法
    
    NSRange                     _clickLinkRange;     // 点击的link的范围
}

@property (nonatomic, strong) UITapGestureRecognizer  *singleTapGuesture; // 点击手势
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGuesture;// 长按手势
@property (nonatomic, strong) UIColor *saveLinkColor;
@end

@implementation TYAttributedLabel

#pragma mark - init

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupProperty];
        _textContainer = [[TYTextContainer alloc]init];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setupProperty];
        _textContainer = [[TYTextContainer alloc]init];
    }
    return self;
}

- (instancetype)initWithTextContainer:(TYTextContainer *)textContainer
{
    if (self = [super init]) {
        [self setupProperty];
        _textContainer = textContainer;
    }
    return self;
}

- (void)setupProperty
{
    if (self.backgroundColor == nil) {
        self.backgroundColor = [UIColor whiteColor];
    }
    self.userInteractionEnabled = YES;
    _highlightedLinkColor = nil;
    _highlightedLinkBackgroundRadius = 2;
    _highlightedLinkBackgroundColor = kSelectAreaColor;
}

- (void)setTextContainer:(TYTextContainer *)attStringCreater
{
    _textContainer = attStringCreater;
    [self resetAllAttributed];
    _preferredMaxLayoutWidth = attStringCreater.textWidth;
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)setDelegate:(id<TYAttributedLabelDelegate>)delegate
{
    if (delegate == _delegate)  return;
    _delegate = delegate;
    
    _delegateFlags.textStorageClickedAtPoint = [delegate respondsToSelector:@selector(attributedLabel:textStorageClicked:atPoint:)];
    _delegateFlags.textStorageLongPressedOnStateAtPoint = [delegate respondsToSelector:@selector(attributedLabel:textStorageLongPressed:onState:atPoint:)];
}

#pragma mark - add textStorage
- (void)addTextStorage:(id<TYTextStorageProtocol>)textStorage
{
    [_textContainer addTextStorage:textStorage];
    [self invalidateIntrinsicContentSize];
}

- (void)addTextStorageArray:(NSArray *)textStorageArray
{
    if (textStorageArray) {
        [_textContainer addTextStorageArray:textStorageArray];
        [self invalidateIntrinsicContentSize];
        [self setNeedsDisplay];
    }
}

- (void)resetAllAttributed
{
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self removeSingleTapGesture];
    [self removeLongPressGesture];
}

#pragma mark reset framesetter
- (void)resetFramesetter
{
    [_textContainer resetRectDictionary];
    [_textContainer resetFrameRef];
    [self setNeedsDisplay];
}
/*
 drawRect在以下情况下会被调用：
 1、如果在UIView初始化时没有设置rect大小，将直接导致drawRect不被自动调用。drawRect调用是在Controller->loadView, Controller->viewDidLoad 两方法之后掉用的.所以不用担心在控制器中,这些View的drawRect就开始画了.这样可以在控制器中设置一些值给View(如果这些View draw的时候需要用到某些变量值).
 2、该方法在调用sizeToFit后被调用，所以可以先调用sizeToFit计算出size。然后系统自动调用drawRect:方法。
 3、通过设置contentMode属性值为UIViewContentModeRedraw。那么将在每次设置或更改frame的时候自动调用drawRect:。
 4、直接调用setNeedsDisplay，或者setNeedsDisplayInRect:触发drawRect:，但是有个前提条件是rect不能为0。
 以上1,2推荐；而3,4不提倡
 drawRect方法使用注意点：
 1、若使用UIView绘图，只能在drawRect：方法中获取相应的contextRef并绘图。如果在其他方法中获取将获取到一个invalidate的ref并且不能用于画图。drawRect：方法不能手动显示调用，必须通过调用setNeedsDisplay 或者 setNeedsDisplayInRect，让系统自动调该方法。
 2、若使用CAlayer绘图，只能在drawInContext: 中（类似于drawRect）绘制，或者在delegate中的相应方法绘制。同样也是调用setNeedDisplay等间接调用以上方法
 3、若要实时画图，不能使用gestureRecognizer，只能使用touchbegan等方法来掉用setNeedsDisplay实时刷新屏幕
 */
// 这个方法，在 [self setNeedsDisplay] 这句代码运行后，会执行
#pragma mark - drawRect
- (void)drawRect:(CGRect)rect {
    
    if (_textContainer == nil ||  _textContainer.attString == nil) {
        return;
    }
    
    [_textContainer createTextContainerWithContentSize:self.bounds.size];
    
    // 文本垂直对齐方式位移
    CGFloat verticalOffset = 0;
    switch (_verticalAlignment) {
        case TYVerticalAlignmentCenter:
            verticalOffset = MAX(0, (CGRectGetHeight(rect) - _textContainer.textHeight)/2);
            break;
        case TYVerticalAlignmentBottom:
            verticalOffset = MAX(0, (CGRectGetHeight(rect) - _textContainer.textHeight));
            break;
        default:
            break;
    }

    CGFloat contextHeight = MAX(CGRectGetHeight(self.bounds) , _textContainer.textHeight);
    //	跟很多底层 API 一样，Core Text 使用 Y翻转坐标系统，而且内容的呈现也是上下翻转的，所以需要通过转换内容将其翻转
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, contextHeight + verticalOffset);
    CGContextScaleCTM(context, 1.0, -1.0);
    // 链接高亮的颜色要有，并且，也有链接storage
    if (_highlightedLinkBackgroundColor && [_textContainer existLinkRectDictionary]) {
        [self drawSelectionAreaFrame:_textContainer.frameRef InRange:_clickLinkRange radius:_highlightedLinkBackgroundRadius bgColor:_highlightedLinkBackgroundColor];
    }
    
    // CTFrameDraw 将 frame 描述到设备上下文
    [self drawText:_textContainer.attString frame:_textContainer.frameRef rect:rect context:context];
    
    // 画其他元素
    [self drawTextStorage];
}

// this code quote M80AttributedLabel
- (void)drawText: (NSAttributedString *)attributedString frame:(CTFrameRef)frame rect: (CGRect)rect context: (CGContextRef)context {
    
    if (_textContainer.numberOfLines > 0)  {
        // 获取行数
        CFArrayRef lines = CTFrameGetLines(frame);
        // 去实际显示的行数
        NSInteger numberOfLines = MIN(_textContainer.numberOfLines, CFArrayGetCount(lines));
        // 获取所有行的位置 x y
        CGPoint lineOrigins[numberOfLines];
        CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
        /*
         truncate
         adj. 截短的；被删节的
         vt. 把…截短；缩短；使成平面
         最后一行是否需要被截断
         这里应该把这个bool值放到这if外面
         */
        BOOL truncateLastLine = (_textContainer.lineBreakMode == kCTLineBreakByTruncatingTail);
        
        // 遍历所有行
        for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
            // 获取每一行的 位置 x, y
            CGPoint lineOrigin = lineOrigins[lineIndex];
            // 设置上下文 位置 为每一行的位置
            CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
            // 获取每一行
            CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
            
            BOOL shouldDrawLine = YES;
            if (lineIndex == numberOfLines - 1 && truncateLastLine) {
                // 绘制最后一行
                // Does the last line need truncation?
                CFRange lastLineRange = CTLineGetStringRange(line);
                // 如果最后一行最后的位置 小于 文字总长度，那么就是尾部截断的
                if (lastLineRange.location + lastLineRange.length < attributedString.length) {
                    // 尾部截断类型
                    CTLineTruncationType truncationType = kCTLineTruncationEnd;
                    // 原文字尾部阶段位置
                    NSUInteger truncationAttributePosition = lastLineRange.location + lastLineRange.length - 1;
                    // 获取尾部文字出的属性
                    NSDictionary *tokenAttributes = [attributedString attributesAtIndex:truncationAttributePosition effectiveRange:NULL];
                    // Ellipses：n 省略号；椭圆；
                    // 用最后的地方的属性和一省略号来创建一个省略号类型的 属性文字
                    NSAttributedString *tokenString = [[NSAttributedString alloc] initWithString:kEllipsesCharacter attributes:tokenAttributes];
                    // 创建一个行
                    CTLineRef truncationToken = CTLineCreateWithAttributedString((CFAttributedStringRef)tokenString);
                    // 把最后一行复制一份
                    NSMutableAttributedString *truncationString = [[attributedString attributedSubstringFromRange:NSMakeRange(lastLineRange.location, lastLineRange.length)] mutableCopy];
                    
                    if (lastLineRange.length > 0) {
                        // Remove last token
                        // 把最后一行最后一个字符删除
                        [truncationString deleteCharactersInRange:NSMakeRange(lastLineRange.length - 1, 1)];
                    }
                    // 给最后一行添加一个省略号
                    [truncationString appendAttributedString:tokenString];
                    
                    // 创建截断行
                    CTLineRef truncationLine = CTLineCreateWithAttributedString((CFAttributedStringRef)truncationString);
                    /*
                     CTLineCreateTruncatedLine
                     @abstract   Creates a truncated line from an existing line.
                     用现有的行，创建一个行
                     
                     @param      line
                     The line that you want to create a truncated line for.
                     你想要把它变成截断行的那个行
                     
                     @param      width
                     The width at which truncation will begin. The line will be truncated if its width is greater than the width passed in this.
                     截断将要发生的地方。准备被截断的行的宽度如果比这个值大的话，行会被截断
                     
                     @param      truncationType
                     The type of truncation to perform if needed.
                     截断行的类型，尾部，中部，头部
                     
                     @param      truncationToken
                     This token will be added to the point where truncation took place to indicate that the line was truncated.
                     截断标识，将会被添加到截断发生处，来标明发生了截断。
                     
                     Usually, the truncation token is the ellipsis character (U+2026).
                     通常截断标识通常是省略号字符
                     
                     If this parameter is set to NULL, then no truncation token is used, and the line is simply cut off.
                     如果这个参数传空，那么就是不用标识符，line会直接截断，什么也不做。
                     
                     The line specified in truncationToken should have a width less than the width specified by the width parameter.
                     截断标识符行，的宽度，应该要比指定View显示的宽度要小
                     
                     If the width of the line specified in truncationToken is greater, this function will return NULL if truncation is needed.
                     截断标识符行，的宽度，比指定View显示的宽度大的话，返回空，在截断发生的时候
                     
                     
                     @result     This function will return a reference to a truncated CTLine object if the call was successful. Otherwise, it will return NULL.
                     这个函数 如果执行成功，会对一个截断过的行强引用
                     否则执行失败就返回NULL了
                     
                     创建截断后的行
                     
                     */
                    CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, rect.size.width, truncationType, truncationToken);
                    if (!truncatedLine) {
                        // If the line is not as wide as the truncationToken, truncatedLine is NULL
                        // 如果不返回一个引用，那么就强制引用一下就好啦
                        truncatedLine = CFRetain(truncationToken);
                    }
                    CFRelease(truncationLine);
                    CFRelease(truncationToken);
                    // 把这行绘制出来
                    CTLineDraw(truncatedLine, context);
                    CFRelease(truncatedLine);
                    // 不要再绘制了
                    shouldDrawLine = NO;
                }
            }
            // 不是最后一行，都要走进来，都会绘制的
            if(shouldDrawLine) {
                CTLineDraw(line, context);
            }
        }
    } else { // 如果一行都木有...直接绘制...什么鬼
        CTFrameDraw(frame,context);
    }
}

#pragma mark - drawTextStorage

- (void)drawTextStorage
{
    // draw storage
    [_textContainer enumerateDrawRectDictionaryUsingBlock:^(id<TYDrawStorageProtocol> drawStorage, CGRect rect) {
        if ([drawStorage conformsToProtocol:@protocol(TYViewStorageProtocol) ]) {
            // 把storage的superView设置为自己
            [(id<TYViewStorageProtocol>)drawStorage setOwnerView:self];
        }
        rect = UIEdgeInsetsInsetRect(rect,drawStorage.margin);
        // 把图片画到context里面，或者把View添加到刚刚设置的superView上，也就是自己
        [drawStorage drawStorageWithRect:rect];
    }];
    // 设置手势
    if ([_textContainer existRunRectDictionary]) {
        if (_delegateFlags.textStorageClickedAtPoint) {
            [self addSingleTapGesture];
        }else {
            [self removeSingleTapGesture];
        }
        if (_delegateFlags.textStorageLongPressedOnStateAtPoint) {
            [self addLongPressGesture];
        }else {
            [self removeLongPressGesture];
        }
    }else {
        [self removeSingleTapGesture];
        [self removeLongPressGesture];
    }
}

#pragma mark - add Gesture
- (void)addSingleTapGesture
{
    if (_singleTapGuesture == nil) {
        // 单指单击
        _singleTapGuesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
        _singleTapGuesture.delegate = self;
        // 增加事件者响应者
        [self addGestureRecognizer:_singleTapGuesture];
    }
}

- (void)removeSingleTapGesture
{
    if (_singleTapGuesture) {
        [self removeGestureRecognizer:_singleTapGuesture];
        _singleTapGuesture = nil;
    }
}

- (void)addLongPressGesture
{
    if (_longPressGuesture == nil) {
        // 长按
        _longPressGuesture = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPress:)];
        [self addGestureRecognizer:_longPressGuesture];
    }
}

- (void)removeLongPressGesture
{
    if (_longPressGuesture) {
        [self removeGestureRecognizer:_longPressGuesture];
        _longPressGuesture = nil;
    }
}

- (CGPoint)covertTapPiont:(CGPoint)piont {
    // 文本垂直对齐方式位移
    CGFloat verticalOffset = 0;
    switch (_verticalAlignment) {
        case TYVerticalAlignmentCenter:
            verticalOffset = MAX(0, (CGRectGetHeight(self.frame) - _textContainer.textHeight)/2);
            break;
        case TYVerticalAlignmentBottom:
            verticalOffset = MAX(0, (CGRectGetHeight(self.frame) - _textContainer.textHeight));
            break;
        default:
            break;
    }
    return CGPointMake(piont.x, piont.y-verticalOffset);
}

#pragma mark - Gesture action

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    CGPoint point = [touch locationInView:self];
    point = [self covertTapPiont:point];
    return [_textContainer enumerateRunRectContainPoint:point viewHeight:CGRectGetHeight(self.frame) successBlock:nil];
}

- (void)singleTap:(UITapGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView:self];
    point = [self covertTapPiont:point];
    __typeof (self) __weak weakSelf = self;
    [_textContainer enumerateRunRectContainPoint:point viewHeight:CGRectGetHeight(self.frame) successBlock:^(id<TYTextStorageProtocol> textStorage){
        if (_delegateFlags.textStorageClickedAtPoint) {
            [_delegate attributedLabel:weakSelf textStorageClicked:textStorage atPoint:point];
        }
    }];
}

- (void)longPress:(UILongPressGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView:self];
    point = [self covertTapPiont:point];
    __typeof (self) __weak weakSelf = self;
    bool didPressContainer = [_textContainer enumerateRunRectContainPoint:point viewHeight:CGRectGetHeight(self.frame) successBlock:^(id<TYTextStorageProtocol> textStorage){
        if (_delegateFlags.textStorageLongPressedOnStateAtPoint) {
                [weakSelf.delegate attributedLabel:weakSelf textStorageLongPressed:textStorage onState:sender.state atPoint:point];
        }
    }];
    // 非响应容器区域响应长按事件
    if (didPressContainer == NO && [weakSelf respondsToSelector:@selector(attributedLabel:lableLongPressOnState:atPoint:)]) {
        [weakSelf.delegate attributedLabel:weakSelf lableLongPressOnState:sender.state atPoint:point];
    }

}

#pragma mark - touches action

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    __block BOOL found = NO;
    if ([_textContainer existLinkRectDictionary]) {
        UITouch *touch = [touches anyObject];
        CGPoint point = [touch locationInView:self];
        point = [self covertTapPiont:point];
        __typeof (self) __weak weakSelf = self;
        [_textContainer enumerateLinkRectContainPoint:point viewHeight:CGRectGetHeight(self.frame) successBlock:^(id<TYLinkStorageProtocol> linkStorage) {
            NSRange curClickLinkRange = linkStorage.realRange;
            [weakSelf setHighlightLinkWithSaveLinkColor:(linkStorage.textColor ? linkStorage.textColor:weakSelf.textContainer.linkColor) linkRange:curClickLinkRange];
            found = YES;
        }];
    }

    if (!found) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    if (![_textContainer existLinkRectDictionary]) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    point = [self covertTapPiont:point];
    __block BOOL isUnderClickLink = NO;
    __block NSRange curClickLinkRange;
    __block UIColor *saveLinkColor = nil;
    
    __typeof (self) __weak weakSelf = self;
    [_textContainer enumerateLinkRectContainPoint:point viewHeight:CGRectGetHeight(self.frame) successBlock:^(id<TYLinkStorageProtocol> linkStorage) {
        curClickLinkRange = linkStorage.realRange;;
        isUnderClickLink = YES;
        saveLinkColor = linkStorage.textColor ? linkStorage.textColor:weakSelf.textContainer.linkColor;
    }];
    
    if (isUnderClickLink) {
        if (!NSEqualRanges(curClickLinkRange, _clickLinkRange)) {
            if (_saveLinkColor) {
                [_textContainer.attString addAttributeTextColor:_saveLinkColor range:_clickLinkRange];
            }
            [self setHighlightLinkWithSaveLinkColor:saveLinkColor linkRange:curClickLinkRange];
        }
    } else if(_clickLinkRange.length > 0) {
        [self resetHighLightLink];
    }
}
//
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    if ([_textContainer existLinkRectDictionary] && _clickLinkRange.length > 0) {
        [self resetHighLightLink];
    }
}

// 长按一个地方的话，大概不到1秒，这个方法就会调用，然后调用touchesCancelled
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    if ([_textContainer existLinkRectDictionary] && _clickLinkRange.length > 0) {
        [self resetHighLightLink];
    }
}

// 设置高亮链接
- (void)setHighlightLinkWithSaveLinkColor:(UIColor *)saveLinkColor linkRange:(NSRange)linkRange
{
    if (NSMaxRange(linkRange) > _textContainer.attString.length) {
        _clickLinkRange.length = 0;
        return;
    }
    _clickLinkRange = linkRange;
    if (_highlightedLinkColor)
    {
        [_textContainer.attString addAttributeTextColor:_highlightedLinkColor range:_clickLinkRange];
        _saveLinkColor = saveLinkColor;
        [self resetFramesetter];
    }else{
        [self setNeedsDisplay];
    }
}

// 取消高亮
- (void)resetHighLightLink
{
    if (_highlightedLinkColor) {
        if (_saveLinkColor) {
            [_textContainer.attString addAttributeTextColor:_saveLinkColor range:_clickLinkRange];
            _saveLinkColor = nil;
        }
        _clickLinkRange.length = 0;
        [self resetFramesetter];
    }else {
        _clickLinkRange.length = 0;
        [self setNeedsDisplay];
    }
}

#pragma mark - draw Rect
// 绘画选择区域
- (void)drawSelectionAreaFrame:(CTFrameRef)frameRef InRange:(NSRange)selectRange radius:(CGFloat)radius bgColor:(UIColor *)bgColor{
    
    NSInteger selectionStartPosition = selectRange.location;
    NSInteger selectionEndPosition = NSMaxRange(selectRange);
    
    if (selectionStartPosition < 0 || selectRange.length <= 0 || selectionEndPosition > _textContainer.attString.length) {
        return;
    }
    
    CFArrayRef lines = CTFrameGetLines(frameRef);
    if (!lines) {
        return;
    }
    // 如同TextContainer里面取出所有storage的点击事件字典一样去遍历
    // 这里只是遍历所有行，并不遍历，每一行的run
    CFIndex count = CFArrayGetCount(lines);
    // 获得每一行的origin坐标
    CGPoint origins[count];
    CTFrameGetLineOrigins(frameRef, CFRangeMake(0,0), origins);
    for (int i = 0; i < count; i++) {
        CGPoint linePoint = origins[i];
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CFRange range = CTLineGetStringRange(line);
        // 1. start和end在一个line,则直接弄完break
        // 如果连接在某一行显示完了，那么渲染完毕直接跳出循环了
        if ([self isPosition:selectionStartPosition inRange:range] && [self isPosition:selectionEndPosition inRange:range]) {
            CGFloat ascent, descent, leading, offset, offset2;
            // 找到一个开始位置在本行中的偏移位置
            offset = CTLineGetOffsetForStringIndex(line, selectionStartPosition, NULL);
            // 找到结束位置在本行中的偏移位置
            offset2 = CTLineGetOffsetForStringIndex(line, selectionEndPosition, NULL);
            // 找到此行的上高下高以及顶部高度
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            // 找到开始位置和结束位置所构成的Rect
            CGRect lineRect = CGRectMake(linePoint.x + offset, linePoint.y - descent, offset2 - offset, ascent + descent);
            // 绘制高亮的文字所在的地方
            [self fillSelectionAreaInRect:lineRect radius:radius bgColor:bgColor];
            break;
        }
        
        // 2. start和end不在一个line
        // 2.1 如果start在line中，则填充Start后面部分区域
        if ([self isPosition:selectionStartPosition inRange:range]) {
            CGFloat ascent, descent, leading, width, offset;
            offset = CTLineGetOffsetForStringIndex(line, selectionStartPosition, NULL);
            width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            CGRect lineRect = CGRectMake(linePoint.x + offset, linePoint.y - descent, width - offset, ascent + descent);
            [self fillSelectionAreaInRect:lineRect radius:radius bgColor:bgColor];
        } // 2.2 如果 start在line前，end在line后，则填充整个区域
        else if (selectionStartPosition < range.location && selectionEndPosition >= range.location + range.length) {
            CGFloat ascent, descent, leading, width;
            width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            CGRect lineRect = CGRectMake(linePoint.x, linePoint.y - descent, width, ascent + descent);
            [self fillSelectionAreaInRect:lineRect radius:radius bgColor:bgColor];
        } // 2.3 如果start在line前，end在line中，则填充end前面的区域,break
        else if (selectionStartPosition < range.location && [self isPosition:selectionEndPosition inRange:range]) {
            CGFloat ascent, descent, leading, width, offset;
            offset = CTLineGetOffsetForStringIndex(line, selectionEndPosition, NULL);
            width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            CGRect lineRect = CGRectMake(linePoint.x, linePoint.y - descent, offset, ascent + descent);
            [self fillSelectionAreaInRect:lineRect radius:radius bgColor:bgColor];
        }
    }
}

- (BOOL)isPosition:(NSInteger)position inRange:(CFRange)range {
    return (position >= range.location && position < range.location + range.length);
}

- (void)fillSelectionAreaInRect:(CGRect)rect radius:(CGFloat)radius bgColor:(UIColor *)bgColor {
    
    CGFloat x = rect.origin.x;
    CGFloat y  = rect.origin.y;
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    
    // 获取CGContext
    CGContextRef context = UIGraphicsGetCurrentContext();
    // 移动到初始点
    CGContextMoveToPoint(context, x + radius, y);
    
    // 绘制第1条线和第1个1/4圆弧
    CGContextAddLineToPoint(context, x + width - radius, y);
    CGContextAddArc(context,x+ width - radius,y+ radius, radius, -0.5 * M_PI, 0.0, 0);
    
    // 绘制第2条线和第2个1/4圆弧
    CGContextAddLineToPoint(context, x + width,y + height - radius);
    CGContextAddArc(context,x+ width - radius,y+ height - radius, radius, 0.0, 0.5 * M_PI, 0);
    
    // 绘制第3条线和第3个1/4圆弧
    CGContextAddLineToPoint(context, x+radius, y+height);
    CGContextAddArc(context, x+radius,y+ height - radius, radius, 0.5 * M_PI, M_PI, 0);
    
    // 绘制第4条线和第4个1/4圆弧
    CGContextAddLineToPoint(context, x,y+ radius);
    CGContextAddArc(context,x+ radius,y+ radius, radius, M_PI, 1.5 * M_PI, 0);
    
    // 闭合路径
    CGContextClosePath(context);
    // 填充颜色
    CGContextSetFillColorWithColor(context, bgColor.CGColor);
    CGContextDrawPath(context, kCGPathFill);
    
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    CGContextSetFillColorWithColor(context, bgColor.CGColor);
//    CGContextFillRect(context, rect);
}

#pragma mark - get Right Height
- (int)getHeightWithWidth:(CGFloat)width
{
    // 是否需要更新frame
    return [_textContainer getHeightWithFramesetter:nil width:width];
}

- (CGSize)getSizeWithWidth:(CGFloat)width
{
    return [_textContainer getSuggestedSizeWithFramesetter:nil width:width];
}

- (void)sizeToFit
{
    [super sizeToFit];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return [self getSizeWithWidth:CGRectGetWidth(self.frame)];
}

- (void)setPreferredMaxLayoutWidth:(CGFloat)preferredMaxLayoutWidth
{
    if (_preferredMaxLayoutWidth != preferredMaxLayoutWidth) {
        _preferredMaxLayoutWidth = preferredMaxLayoutWidth;
        // 只要改变宽度，就会让原先的布局失效
        [self invalidateIntrinsicContentSize];
    }
}
/*
 这个属性是 为了在ixib的时候，自定义View和系统的自动布局系统沟通的方式
 但是这个属性计算的时候，一定要自己计算，不能再基于内控控件的frame
 
 如果不设置_preferredMaxLayoutWidth，这个属性就会返回0
 */
- (CGSize)intrinsicContentSize
{
    return [self getSizeWithWidth:_preferredMaxLayoutWidth];
}

#pragma mark - set right frame
- (void)setFrameWithOrign:(CGPoint)orign Width:(CGFloat)width
{
    // 获得高度
    int height = [self getHeightWithWidth:width];
    
    // 设置frame
    [self setFrame:CGRectMake(orign.x, orign.y, width, height)];
}

- (void)dealloc
{
    _textContainer = nil;
}

#pragma mark - getter

- (NSString *)text{
    return _textContainer.text;
}

- (NSAttributedString *)attributedText
{
    return _textContainer.attributedText;
}

- (NSInteger)numberOfLines
{
    return _textContainer.numberOfLines;
}

- (UIColor *)textColor
{
    return _textContainer.textColor;
}

- (UIFont *)font
{
    return _textContainer.font;
}

- (UIColor *)strokeColor
{
    return _textContainer.strokeColor;
}

- (unichar)strokeWidth
{
    return _textContainer.strokeWidth;
}

- (unichar)characterSpacing
{
    return _textContainer.characterSpacing;
}

- (CGFloat)linesSpacing
{
    return _textContainer.linesSpacing;
}

- (CGFloat)paragraphSpacing
{
    return _textContainer.paragraphSpacing;
}

- (CTLineBreakMode)lineBreakMode
{
    return _textContainer.lineBreakMode;
}

- (CTTextAlignment)textAlignment
{
    return _textContainer.textAlignment;
}

- (CGFloat)textHeight{
    return _textContainer.textHeight;
}

- (UIColor *)linkColor
{
    return _textContainer.linkColor;
}

- (BOOL)isWidthToFit
{
    return _textContainer.isWidthToFit;
}

#pragma mark - setter

- (void)setText:(NSString *)text
{
    [_textContainer setText:text];
    [self resetAllAttributed];
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [_textContainer setAttributedText:attributedText];
    [self resetAllAttributed];
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)setNumberOfLines:(NSInteger)numberOfLines
{
    [_textContainer setNumberOfLines:numberOfLines];
}

- (void)setTextColor:(UIColor *)textColor
{
    [_textContainer setTextColor:textColor];
    [self setNeedsDisplay];
}

- (void)setFont:(UIFont *)font
{
    [_textContainer setFont:font];
    [self setNeedsDisplay];
}

- (void)setStrokeWidth:(unichar)strokeWidth
{
    [_textContainer setStrokeWidth:strokeWidth];
    [self setNeedsDisplay];
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    [_textContainer setStrokeColor:strokeColor];
    [self setNeedsDisplay];
}

- (void)setCharacterSpacing:(unichar)characterSpacing
{
    [_textContainer setCharacterSpacing:characterSpacing];
    [self setNeedsDisplay];
}

- (void)setLinesSpacing:(CGFloat)linesSpacing
{
    [_textContainer setLinesSpacing:linesSpacing];
    [self setNeedsDisplay];
}

- (void)setParagraphSpacing:(CGFloat)paragraphSpacing
{
    [_textContainer setParagraphSpacing:paragraphSpacing];
    [self setNeedsDisplay];
}

- (void)setLineBreakMode:(CTLineBreakMode)lineBreakMode
{
    [_textContainer setLineBreakMode:lineBreakMode];
    [self setNeedsDisplay];
}

- (void)setTextAlignment:(CTTextAlignment)textAlignment
{
    [_textContainer setTextAlignment:textAlignment];
    [self setNeedsDisplay];
}

- (void)setLinkColor:(UIColor *)linkColor
{
    [_textContainer setLinkColor:linkColor];
}

- (void)setIsWidthToFit:(BOOL)isWidthToFit
{
    [_textContainer setIsWidthToFit:isWidthToFit];
}

@end

#pragma mark - append attributedString

@implementation TYAttributedLabel (AppendAttributedString)

- (void)appendText:(NSString *)text
{
    [_textContainer appendText:text];
    /*
     使无效，固有的 内容大小
     让固有的大小失效，然后重绘
     */
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)appendTextAttributedString:(NSAttributedString *)attributedText
{
    [_textContainer appendTextAttributedString:attributedText];
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (void)appendTextStorage:(id<TYAppendTextStorageProtocol>)textStorage
{
    if (textStorage) {
        [_textContainer appendTextStorage:textStorage];
        [self invalidateIntrinsicContentSize];
        [self setNeedsDisplay];
    }
}

- (void)appendTextStorageArray:(NSArray *)textStorageArray
{
    if (textStorageArray) {
        [_textContainer appendTextStorageArray:textStorageArray];
        [self invalidateIntrinsicContentSize];
        [self setNeedsDisplay];
    }
}

@end

@implementation TYAttributedLabel (Link)

#pragma mark - addLink
- (void)addLinkWithLinkData:(id)linkData range:(NSRange)range
{
    [self addLinkWithLinkData:linkData linkColor:nil range:range];
}

- (void)addLinkWithLinkData:(id)linkData linkColor:(UIColor *)linkColor range:(NSRange )range;
{
    [self addLinkWithLinkData:linkData linkColor:linkColor underLineStyle:kCTUnderlineStyleSingle range:range];
}

- (void)addLinkWithLinkData:(id)linkData linkColor:(UIColor *)linkColor underLineStyle:(CTUnderlineStyle)underLineStyle range:(NSRange )range
{
    [_textContainer addLinkWithLinkData:linkData linkColor:linkColor underLineStyle:underLineStyle range:range];
    [self setNeedsDisplay];
}

#pragma mark - appendLink
- (void)appendLinkWithText:(NSString *)linkText linkFont:(UIFont *)linkFont linkData:(id)linkData
{
    [self appendLinkWithText:linkText linkFont:linkFont linkColor:nil linkData:linkData];
}

- (void)appendLinkWithText:(NSString *)linkText linkFont:(UIFont *)linkFont linkColor:(UIColor *)linkColor linkData:(id)linkData
{
    [self appendLinkWithText:linkText linkFont:linkFont linkColor:linkColor underLineStyle:kCTUnderlineStyleSingle linkData:linkData];
}

- (void)appendLinkWithText:(NSString *)linkText linkFont:(UIFont *)linkFont linkColor:(UIColor *)linkColor underLineStyle:(CTUnderlineStyle)underLineStyle linkData:(id)linkData
{
    [_textContainer appendLinkWithText:linkText linkFont:linkFont linkColor:linkColor underLineStyle:underLineStyle linkData:linkData];
    [self setNeedsDisplay];
}

@end

@implementation TYAttributedLabel (UIImage)

#pragma mark addImage

- (void)addImage:(UIImage *)image range:(NSRange)range size:(CGSize)size alignment:(TYDrawAlignment)alignment
{
    [_textContainer addImage:image range:range size:size alignment:alignment];
}

- (void)addImage:(UIImage *)image range:(NSRange)range size:(CGSize)size
{
    [self addImage:image range:range size:size alignment:TYDrawAlignmentTop];
}

- (void)addImage:(UIImage *)image range:(NSRange)range
{
    [self addImage:image range:range size:image.size];
}

- (void)addImageWithName:(NSString *)imageName range:(NSRange)range size:(CGSize)size alignment:(TYDrawAlignment)alignment
{
    [_textContainer addImageWithName:imageName range:range size:size alignment:alignment];
}

- (void)addImageWithName:(NSString *)imageName range:(NSRange)range size:(CGSize)size
{
    [self addImageWithName:imageName range:range size:size alignment:TYDrawAlignmentTop];
}

- (void)addImageWithName:(NSString *)imageName range:(NSRange)range
{
    [self addImageWithName:imageName range:range size:CGSizeMake(self.font.pointSize, self.font.ascender)];
    
}

#pragma mark - appendImage

- (void)appendImage:(UIImage *)image size:(CGSize)size alignment:(TYDrawAlignment)alignment
{
    [_textContainer appendImage:image size:size alignment:alignment];
}

- (void)appendImage:(UIImage *)image size:(CGSize)size
{
    [self appendImage:image size:size alignment:TYDrawAlignmentTop];
}

- (void)appendImage:(UIImage *)image
{
    [self appendImage:image size:image.size];
}

- (void)appendImageWithName:(NSString *)imageName size:(CGSize)size alignment:(TYDrawAlignment)alignment
{
    [_textContainer appendImageWithName:imageName size:size alignment:alignment];
}

- (void)appendImageWithName:(NSString *)imageName size:(CGSize)size
{
    [self appendImageWithName:imageName size:size alignment:TYDrawAlignmentTop];
}

- (void)appendImageWithName:(NSString *)imageName
{
    [self appendImageWithName:imageName size:CGSizeMake(self.font.pointSize, self.font.ascender)];
    
}

@end

@implementation TYAttributedLabel (UIView)

#pragma mark - addView

- (void)addView:(UIView *)view range:(NSRange)range alignment:(TYDrawAlignment)alignment
{
    [_textContainer addView:view range:range alignment:alignment];
}

- (void)addView:(UIView *)view range:(NSRange)range
{
    [self addView:view range:range alignment:TYDrawAlignmentTop];
}

#pragma mark - appendView

- (void)appendView:(UIView *)view alignment:(TYDrawAlignment)alignment
{
    [_textContainer appendView:view alignment:alignment];
}

- (void)appendView:(UIView *)view
{
    [self appendView:view alignment:TYDrawAlignmentTop];
}


@end
