//
//  TYDrawStorage.m
//  TYAttributedLabelDemo
//
//  Created by tanyang on 15/4/8.
//  Copyright (c) 2015年 tanyang. All rights reserved.
//

#import "TYDrawStorage.h"
#import <CoreText/CoreText.h>

@interface TYDrawStorage (){
    CGFloat         _fontAscent;
    CGFloat         _fontDescent;
    
    NSRange         _fixRange;
}
@end

@implementation TYDrawStorage

#pragma mark - protocol

- (void)currentReplacedStringNum:(NSInteger)replacedStringNum
{
    _fixRange = [self fixRange:_range replaceStringNum:replacedStringNum];
}
/*
 看这里： https://www.jianshu.com/p/3da70c418fe7
 
 familyName 字体家族的名字
 fontName 字体的名字
 pointSize 字体大小
 ascender 基准线以上的高度
 descender 基准线以下的高度
 capHeight 大小的高度
 xHeight 小写x的高度
 lineHeight 当前字体下的行高
 leading 行间距（一般为0）
 
 UIFont *font = [UIFont systemFontOfSize:14];
 NSLog(@"font.pointSize = %f,font.ascender = %f,font.descender = %f,font.capHeight = %f,font.xHeight = %f,font.lineHeight = %f,font.leading = %f",font.pointSize,font.ascender,font.descender,font.capHeight,font.xHeight,font.lineHeight,font.leading);
 
 font.pointSize = 14.000000,
 font.ascender = 13.330078,
 font.descender = -3.376953,
 font.capHeight = 9.864258,
 font.xHeight = 7.369141,
 font.lineHeight = 16.707031,
 font.leading = 0.000000
 
 其中可以很明显的看到：
 
 设置的字体大小就是 pointSize
 ascender + descender = lineHeight
 3.实际行与行之间就是存在间隙的，间隙大小即为 lineHeight - pointSize，在富文本中设置行高的时候，其实际文字间的距离就是加上这个距离的。（原来一直错误的理解文字间的距离就是行间距）
 */
- (void)setTextfontAscent:(CGFloat)ascent descent:(CGFloat)descent;
{
    _fontAscent = ascent;
    _fontDescent = -descent;
}

- (void)addTextStorageWithAttributedString:(NSMutableAttributedString *)attributedString
{
    NSRange range = _fixRange;
    if (range.location == NSNotFound) {
        return;
    }else {
        // 用空白替换
        [attributedString replaceCharactersInRange:range withString:[self spaceReplaceString]];
        // 修正range
        range = NSMakeRange(range.location, 1);
        _realRange = range;
    }
    
    // 设置合适的对齐
    [self setAppropriateAlignment];
    
    // 添加文本属性和runDelegate
    [self addRunDelegateWithAttributedString:attributedString range:range];
}

- (NSAttributedString *)appendTextStorageAttributedString
{
    // 创建空字符属性文本
    // 意思就是创建了一个空格字符串
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithString:[self spaceReplaceString]];
    // 修正range
    _range = NSMakeRange(0, 1);
    
    // 设置合适的对齐
    [self setAppropriateAlignment];
    
    // 添加文本属性和runDelegate
    [self addRunDelegateWithAttributedString:attributedString range:_range];
    return attributedString;
}

- (void)drawStorageWithRect:(CGRect)rect
{
    
}

#pragma mark - public

- (CGFloat)getDrawRunAscentHeight
{
    CGFloat ascent = 0;
    CGFloat height = self.size.height+_margin.bottom+_margin.top;
    switch (_drawAlignment)
    {
        case TYDrawAlignmentTop:
            ascent = height - _fontDescent;
            break;
        case TYDrawAlignmentCenter:
        {
            CGFloat baseLine = (_fontAscent + _fontDescent) / 2 - _fontDescent;
            ascent = height / 2 + baseLine;
            break;
        }
        case TYDrawAlignmentBottom:
            ascent = _fontAscent;
            break;
        default:
            break;
    }
    return ascent;
}

- (CGFloat)getDrawRunWidth
{
    return self.size.width+_margin.left+_margin.right;
}

- (CGFloat)getDrawRunDescentHeight
{
    CGFloat descent = 0;
    CGFloat height = self.size.height+_margin.bottom+_margin.top;
    switch (_drawAlignment)
    {
        case TYDrawAlignmentTop:
            descent = _fontDescent;
            break;
        case TYDrawAlignmentCenter:
        {
            CGFloat baseLine = (_fontAscent + _fontDescent) / 2 - _fontDescent;
            descent = height / 2 - baseLine;
            break;
        }
        case TYDrawAlignmentBottom:
            descent = height - _fontAscent;
            break;
        default:
            break;
    }
    
    return descent;
}

- (void)DrawRunDealloc
{
    
}

#pragma mark - private

- (NSString *)spaceReplaceString
{
    // 替换字符
    unichar objectReplacementChar           = 0xFFFC;
    NSString *objectReplacementString       = [NSString stringWithCharacters:&objectReplacementChar length:1];
    return objectReplacementString;
}

- (void)setAppropriateAlignment
{
    // 判断size 大小 小于 _fontAscent 把对齐设为中心 更美观
    // 这里写的挺好的，很细心
    if (_size.height <= _fontAscent + _fontDescent) {
        _drawAlignment = TYDrawAlignmentCenter;
    }
}

- (NSRange)fixRange:(NSRange)range replaceStringNum:(NSInteger)replaceStringNum
{
    NSRange fixRange = range;
    if (range.length <= 1 || replaceStringNum < 0)
        return fixRange;
    
    NSInteger location = range.location - replaceStringNum;
    NSInteger length = range.length - replaceStringNum;
    
    if (location < 0 && length > 0) {
        fixRange = NSMakeRange(range.location, length);
    }else if (location < 0 && length <= 0){
        fixRange = NSMakeRange(NSNotFound, 0);
    }else {
        fixRange = NSMakeRange(range.location - replaceStringNum, range.length);
    }
    return fixRange;
}

// 添加文本属性和runDelegate
- (void)addRunDelegateWithAttributedString:(NSMutableAttributedString *)attributedString range:(NSRange)range
{
    // 添加文本属性和runDelegate
    [attributedString addAttribute:kTYTextRunAttributedName value:self range:range];
    
    //为图片设置CTRunDelegate,delegate决定留给显示内容的空间大小
    CTRunDelegateCallbacks runCallbacks;
    runCallbacks.version = kCTRunDelegateVersion1;
    runCallbacks.dealloc = TYTextRunDelegateDeallocCallback;
    runCallbacks.getAscent = TYTextRunDelegateGetAscentCallback;
    runCallbacks.getDescent = TYTextRunDelegateGetDescentCallback;
    runCallbacks.getWidth = TYTextRunDelegateGetWidthCallback;
    
    CTRunDelegateRef runDelegate = CTRunDelegateCreate(&runCallbacks, (__bridge void *)(self));
    [attributedString addAttribute:(__bridge_transfer NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:range];
    CFRelease(runDelegate);
}

//CTRun的回调，销毁内存的回调
void TYTextRunDelegateDeallocCallback( void* refCon ){
    //TYDrawRun *textRun = (__bridge TYDrawRun *)refCon;
    //[textRun DrawRunDealloc];
}

//CTRun的回调，获取高度
CGFloat TYTextRunDelegateGetAscentCallback( void *refCon ){
    
    TYDrawStorage *drawStorage = (__bridge TYDrawStorage *)refCon;
    return [drawStorage getDrawRunAscentHeight];
}

CGFloat TYTextRunDelegateGetDescentCallback(void *refCon){
    TYDrawStorage *drawStorage = (__bridge TYDrawStorage *)refCon;
    return [drawStorage getDrawRunDescentHeight];
}

//CTRun的回调，获取宽度
CGFloat TYTextRunDelegateGetWidthCallback(void *refCon){
    
    TYDrawStorage *drawStorage = (__bridge TYDrawStorage *)refCon;
    return [drawStorage getDrawRunWidth];
}

@end
