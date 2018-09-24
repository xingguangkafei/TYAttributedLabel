//
//  NSMutableAttributedString+TY.m
//  TYAttributedLabelDemo
//
//  Created by tanyang on 15/4/8.
//  Copyright (c) 2015年 tanyang. All rights reserved.
//

#import "NSMutableAttributedString+TY.h"

@implementation NSMutableAttributedString (TY)

#pragma mark - 文本颜色属性
- (void)addAttributeTextColor:(UIColor*)color
{
    [self addAttributeTextColor:color range:NSMakeRange(0, [self length])];
}

- (void)addAttributeTextColor:(UIColor*)color range:(NSRange)range
{
    if (color.CGColor)
    {
        // 用 CoreText属性，用NSAttributeString接口改变文本颜色
        [self removeAttribute:(NSString *)kCTForegroundColorAttributeName range:range];
        
        [self addAttribute:(NSString *)kCTForegroundColorAttributeName
                     value:(id)color.CGColor
                     range:range];
    }
    
}

#pragma mark - 文本字体属性
- (void)addAttributeFont:(UIFont *)font
{
    [self addAttributeFont:font range:NSMakeRange(0, [self length])];
}

- (void)addAttributeFont:(UIFont *)font range:(NSRange)range
{
    if (font)
    {
        // 这里用CoreText类型的 文字属性，感觉用NSAttributeString里的应该效果一样
        [self removeAttribute:(NSString*)kCTFontAttributeName range:range];
        // 用CoreText创建文字字体属性
        CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, nil);
        if (nil != fontRef)
        {   // 用 NSAttributeSting 接口设置字体属性
            [self addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)fontRef range:range];
            CFRelease(fontRef);
        }
    }
}

#pragma mark - 文本字符间隔属性
- (void)addAttributeCharacterSpacing:(unichar)characterSpacing
{
    [self addAttributeCharacterSpacing:characterSpacing range:NSMakeRange(0, self.length)];
}

- (void)addAttributeCharacterSpacing:(unichar)characterSpacing range:(NSRange)range
{
    [self removeAttribute:(id)kCTKernAttributeName range:range];
    // 这个改变字间距的value的创建，也是这么皮，怪不得githubi另外一哥们那么直接设置没有效果
    CFNumberRef num =  CFNumberCreate(kCFAllocatorDefault,kCFNumberSInt8Type,&characterSpacing);
    [self addAttribute:(id)kCTKernAttributeName value:(__bridge id)num range:range];
    CFRelease(num);
}

#pragma mark - 文本下划线属性
- (void)addAttributeUnderlineStyle:(CTUnderlineStyle)style
                 modifier:(CTUnderlineStyleModifiers)modifier
{
    [self addAttributeUnderlineStyle:style
                   modifier:modifier
                      range:NSMakeRange(0, self.length)];
}

- (void)addAttributeUnderlineStyle:(CTUnderlineStyle)style
                 modifier:(CTUnderlineStyleModifiers)modifier
                    range:(NSRange)range
{
    [self removeAttribute:(NSString *)kCTUnderlineColorAttributeName range:range];
    
    if (style != kCTUnderlineStyleNone) {
        [self addAttribute:(NSString *)kCTUnderlineStyleAttributeName
                     value:[NSNumber numberWithInt:(style|modifier)]
                     range:range];
    }
    
}

#pragma mark - 文本空心字及颜色

- (void)addAttributeStrokeWidth:(unichar)strokeWidth
                    strokeColor:(UIColor *)strokeColor
{
    [self addAttributeStrokeWidth:strokeWidth strokeColor:strokeColor range:NSMakeRange(0, self.length)];
}

- (void)addAttributeStrokeWidth:(unichar)strokeWidth
                    strokeColor:(UIColor *)strokeColor
                          range:(NSRange)range
{
    [self removeAttribute:(id)kCTStrokeWidthAttributeName range:range];
    if (strokeWidth > 0) {
        /* synonym：n. 同义词；同义字
         kCFAllocatorDefault 和 NULL 同一个意思
         用CFNumber结构体 ，创建一个表达颜色的value
         用NSAttributeString接口，使用这个参数
         */
        CFNumberRef num = CFNumberCreate(kCFAllocatorDefault,kCFNumberSInt8Type,&strokeWidth);
        
        [self addAttribute:(id)kCTStrokeWidthAttributeName value:(__bridge id)num range:range];
    }
    
    [self removeAttribute:(id)kCTStrokeColorAttributeName range:range];
    if (strokeColor) {
        // 这个value的传值，是真的皮，改变填充颜色和填充宽度，竟然方式差别这么大
        [self addAttribute:(id)kCTStrokeColorAttributeName value:(id)strokeColor.CGColor range:range];
    }
    
}

#pragma mark - 文本段落样式属性
- (void)addAttributeAlignmentStyle:(CTTextAlignment)textAlignment
                    lineSpaceStyle:(CGFloat)linesSpacing
               paragraphSpaceStyle:(CGFloat)paragraphSpacing
                    lineBreakStyle:(CTLineBreakMode)lineBreakMode
{
    [self addAttributeAlignmentStyle:textAlignment lineSpaceStyle:linesSpacing paragraphSpaceStyle:paragraphSpacing lineBreakStyle:lineBreakMode range:NSMakeRange(0, self.length)];
}

- (void)addAttributeAlignmentStyle:(CTTextAlignment)textAlignment
                    lineSpaceStyle:(CGFloat)linesSpacing
               paragraphSpaceStyle:(CGFloat)paragraphSpacing
                    lineBreakStyle:(CTLineBreakMode)lineBreakMode
                             range:(NSRange)range
{
    [self removeAttribute:(id)kCTParagraphStyleAttributeName range:range];
    
    // 创建文本对齐方式
    CTParagraphStyleSetting alignmentStyle;
    alignmentStyle.spec = kCTParagraphStyleSpecifierAlignment;//指定为对齐属性
    alignmentStyle.valueSize = sizeof(textAlignment);
    alignmentStyle.value = &textAlignment;
    
    // 创建文本行间距
    CTParagraphStyleSetting lineSpaceStyle;
    lineSpaceStyle.spec = kCTParagraphStyleSpecifierLineSpacingAdjustment;
    lineSpaceStyle.valueSize = sizeof(linesSpacing);
    lineSpaceStyle.value = &linesSpacing;
    
    //段落间距
    CTParagraphStyleSetting paragraphSpaceStyle;
    paragraphSpaceStyle.spec = kCTParagraphStyleSpecifierParagraphSpacing;
    paragraphSpaceStyle.value = &paragraphSpacing;
    paragraphSpaceStyle.valueSize = sizeof(paragraphSpacing);
    
    //换行模式
    CTParagraphStyleSetting lineBreakStyle;
    lineBreakStyle.spec = kCTParagraphStyleSpecifierLineBreakMode;
    lineBreakStyle.value = &lineBreakMode;
    lineBreakStyle.valueSize = sizeof(lineBreakMode);
    
    // 创建样式数组
    CTParagraphStyleSetting settings[] = {alignmentStyle ,lineSpaceStyle, paragraphSpaceStyle, lineBreakStyle};
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));	// 设置样式
    
    // 设置段落属性
    [self addAttribute:(id)kCTParagraphStyleAttributeName value:(id)CFBridgingRelease(paragraphStyle) range:range];
}

@end
