//
//  Tokenizer.m
//  iGitpad
//
//  Created by Johannes Lund on 2012-11-24.
//
//

//  This file builds upon the work of Kristian Kraljic
//
//  RegexHighlightView.m
//  Simple Objective-C Syntax Highlighter
//
//  Created by Kristian Kraljic on 30/08/12.
//  Copyright (c) 2012 Kristian Kraljic (dikrypt.com, ksquared.de). All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "JLTokenizer.h"
#import "JLTextView.h"
#import <CoreText/CoreText.h>

NSString *const kTokenizerTypeText = @"text";
NSString *const kTokenizerTypeBackground = @"background";
NSString *const kTokenizerTypeComment = @"comment";
NSString *const kTokenizerTypeDocumentationComment = @"documentation_comment";
NSString *const kTokenizerTypeDocumentationCommentKeyword = @"documentation_comment_keyword";
NSString *const kTokenizerTypeString = @"string";
NSString *const kTokenizerTypeCharacter = @"character";
NSString *const kTokenizerTypeNumber = @"number";
NSString *const kTokenizerTypeKeyword = @"keyword";
NSString *const kTokenizerTypePreprocessor = @"preprocessor";
NSString *const kTokenizerTypeURL = @"url";
NSString *const kTokenizerTypeAttribute = @"attribute";
NSString *const kTokenizerTypeProject = @"project";
NSString *const kTokenizerTypeOther = @"other";
NSString *const kTokenizerTypeOtherMethodNames = @"other_method_names";
NSString *const kTokenizerTypeOtherClassNames = @"other_class_names";

@interface NSMutableAttributedString (Regex)
- (void)addRanges:(NSArray *)array withColor:(UIColor *)color;
- (void)addRanges:(NSArray *)array withAttributes:(NSDictionary *)dic;
- (NSArray *)allMatchesOfPattern:(NSString *)pattern inString:(NSString *)string;

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color andDescription:(NSString *)description;
- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color range:(NSRange)range andDescription:(NSString *)description;
- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color group:(int)index range:(NSRange)range andDescription:(NSString *)description;
- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options andDescription:(NSString *)description;
- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options range:(NSRange)range andDescription:(NSString *)description;
- (void)removeAttribute:(NSString *)name withValue:(id)compareValue range:(NSRange)range;
@end

@interface JLTokenizer ()

+ (NSDictionary*)highlightTheme:(RegexHighlightViewTheme)theme;

@end

@implementation JLTokenizer
@synthesize theme = _theme;

- (NSMutableAttributedString *)tokenizeAttributedString:(NSMutableAttributedString *)string withRecentTextViewChange:(TextViewChange *)options {
    UIColor *color;
    color = [UIColor blueColor];
    
    if (string.length == 0) return string;
    
    NSRange newWord = NSMakeRange(options.range.location, options.replacementText.length);
    NSRange currentLine = NSMakeRange(0, string.length);
    NSRange stringRange = currentLine;
    if (options) {
        NSRange start = [string.string rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, newWord.location)];
        NSRange stop = [string.string rangeOfString:@"\n" options:0 range:NSMakeRange(newWord.length+newWord.location, string.length-(newWord.location+newWord.length))];
        
        int location = MIN(MAX(start.location, 0), string.length);
        int length = MIN(MAX(0,(stop.location+stop.length-location)), string.length-location);
        
        currentLine = NSMakeRange(location, length);
    }
    
    NSDictionary *dic = self.colorDictionary;
    
    //Clear the comments to later be rebuilt
    UIColor *compareColor = dic[kTokenizerTypeComment];
    [string removeAttribute:(NSString *)kCTForegroundColorAttributeName withValue:compareColor range:stringRange];
    
    [string removeAttribute:(NSString *)kCTForegroundColorAttributeName range:currentLine];
    [string addAttribute:(NSString *)kCTForegroundColorAttributeName value:dic[kTokenizerTypeText] range:currentLine];
    
    //TODO: Make this... better
    
    color = dic[kTokenizerTypeNumber];
    
    [string addRegularExpressionWithPattern:@"(?<=\\s)\\d+" withColor:color range:currentLine  andDescription:@"Numbers"];
    
    [string addRegularExpressionWithPattern:@"@\\s*[\(|\{|\[]" withColor:color andDescription:@"New literals"];
    
    //C – functions and similiar
    color = dic[kTokenizerTypeOtherMethodNames];
    [string addRegularExpressionWithPattern:@"\\w+\\s*(?>\\(.*\\)" withColor:color group:1 range:currentLine andDescription:@"C function names"];
    
    //Dot notation
    [string addRegularExpressionWithPattern:@"\\.(\\w+)" withColor:color group:1 range:currentLine andDescription:@"Dot notation"];
    
    //Method calls
    [string addRegularExpressionWithPattern:@"\\[\\w+\\s+(\\w+)\\]" withColor:color group:1   range:currentLine andDescription:@"Method calls"];
    [string addRegularExpressionWithPattern:@"(?<=\\w+):\\s*[^\\s;\\]]+" withColor:color group:1 range:currentLine andDescription:@"Method calls parts"];
    
    color = dic[kTokenizerTypeOtherClassNames];
    [string addRegularExpressionWithPattern:@"(\\b(?>NS|UI))\\w+\\b" withColor:color range:currentLine andDescription:@"UIKit and NS"];
    
    color = dic[kTokenizerTypeKeyword];
    [string addRegularExpressionWithPattern:@"(?<=\\b)(?>true|false|yes|no|Khalid|readonly)(\\b)" withColor:color range:currentLine andDescription:@"Keywords"];
    
    
    [string addRegularExpressionWithPattern:@"@[a-zA-Z0-9_]+" withColor:color range:currentLine andDescription:@"@things"];
    
    color = dic[kTokenizerTypePreprocessor];
    [string addRegularExpressionWithPattern:@"#.*+\n" withColor:color range:currentLine andDescription:@"Prefixes"];
    
    color = dic[kTokenizerTypeString];
    [string addRegularExpressionWithPattern:@"(\"|@\")[^\"]*(@\"|\")" withColor:color andDescription:@"Strings"];
    
    color = dic[kTokenizerTypeComment];
    [string addRegularExpressionWithPattern:@"//.*+\n" withColor:color andDescription:@"Comments"];
    
    [string addRegularExpressionWithPattern:@"/\\*([^*]|[\\r\\n]|(\\*+([^*/]|[\\r\\n])))*\\*+/" withColor:color andDescription:@"Comments"];
    
    return string;
}

#pragma mark - Pattern help

- (NSString *)patternBetweenString:(NSString *)start andString:(NSString *)stop
{
    return nil;
}

#pragma mark - Color shemes



-(void)setTheme:(RegexHighlightViewTheme)theme
{
    self.colorDictionary = [JLTokenizer highlightTheme:theme];
    _theme = theme;
    
    //Set font, text color and background color back to default
    UIColor* backgroundColor = self.colorDictionary[kTokenizerTypeBackground];
    if(backgroundColor)
        self.backgroundColor = backgroundColor;
    else self.backgroundColor = [UIColor whiteColor];
}

- (NSDictionary *)colorDictionary
{
    if (!_colorDictionary) {
        _colorDictionary = [JLTokenizer highlightTheme:self.theme];
    }
    return _colorDictionary;
}

- (NSArray *)themes
{
    if (!_themes) _themes = @[@(kTokenizerThemeDefault),@(kTokenizerThemeDusk)];
    return _themes;
}

- (RegexHighlightViewTheme)theme
{
    if (!_theme) _theme = kTokenizerThemeDefault;
    return _theme;
}

- (void)setTextView:(JLTextView *)textView
{
    _textView = textView;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [self.textView.tableView setBackgroundColor:backgroundColor];
    
    _backgroundColor = backgroundColor;
}

// Just a bunch of colors
+ (NSDictionary*)highlightTheme:(RegexHighlightViewTheme)theme {
    //Check if the highlight theme has already been defined
    NSDictionary* themeColor = nil;
    //If not define the theme and return it
    switch(theme) {
        case kTokenizerThemeDefault:
            themeColor = @{kTokenizerTypeText: [UIColor colorWithRed:0.0/255 green:0.0/255 blue:0.0/255 alpha:1],
                           kTokenizerTypeBackground: [UIColor colorWithRed:255.0/255 green:255.0/255 blue:255.0/255 alpha:1],
                           kTokenizerTypeComment: [UIColor colorWithRed:0.0/255 green:131.0/255 blue:39.0/255 alpha:1],
                           kTokenizerTypeDocumentationComment: [UIColor colorWithRed:0.0/255 green:131.0/255 blue:39.0/255 alpha:1],
                           kTokenizerTypeDocumentationCommentKeyword: [UIColor colorWithRed:0.0/255 green:76.0/255 blue:29.0/255 alpha:1],
                           kTokenizerTypeString: [UIColor colorWithRed:211.0/255 green:45.0/255 blue:38.0/255 alpha:1],
                           kTokenizerTypeCharacter: [UIColor colorWithRed:40.0/255 green:52.0/255 blue:206.0/255 alpha:1],
                           kTokenizerTypeNumber: [UIColor colorWithRed:40.0/255 green:52.0/255 blue:206.0/255 alpha:1],
                           kTokenizerTypeKeyword: [UIColor colorWithRed:188.0/255 green:49.0/255 blue:156.0/255 alpha:1],
                           kTokenizerTypePreprocessor: [UIColor colorWithRed:120.0/255 green:72.0/255 blue:48.0/255 alpha:1],
                           kTokenizerTypeURL: [UIColor colorWithRed:21.0/255 green:67.0/255 blue:244.0/255 alpha:1],
                           kTokenizerTypeAttribute: [UIColor colorWithRed:150.0/255 green:125.0/255 blue:65.0/255 alpha:1],
                           kTokenizerTypeProject: [UIColor colorWithRed:77.0/255 green:129.0/255 blue:134.0/255 alpha:1],
                           kTokenizerTypeOther: [UIColor colorWithRed:113.0/255 green:65.0/255 blue:163.0/255 alpha:1],
                           kTokenizerTypeOtherMethodNames :  [UIColor colorWithHex:@"7040a6" alpha:1],
                           kTokenizerTypeOtherClassNames :  [UIColor colorWithHex:@"7040a6" alpha:1]
                           
                           
                           
                           };
            break;
        case kTokenizerThemeDusk:
            themeColor = @{kTokenizerTypeText: [UIColor whiteColor],
                           kTokenizerTypeBackground: [UIColor colorWithRed:30.0/255.0 green:32.0/255.0 blue:40.0/255.0 alpha:1],
                           kTokenizerTypeComment: [UIColor colorWithRed:72.0/255 green:190.0/255 blue:102.0/255 alpha:1],
                           kTokenizerTypeDocumentationComment: [UIColor colorWithRed:72.0/255 green:190.0/255 blue:102.0/255 alpha:1],
                           kTokenizerTypeDocumentationCommentKeyword: [UIColor colorWithRed:72.0/255 green:190.0/255 blue:102.0/255 alpha:1],
                           kTokenizerTypeString: [UIColor colorWithRed:230.0/255 green:66.0/255 blue:75.0/255 alpha:1],
                           kTokenizerTypeCharacter: [UIColor colorWithRed:139.0/255 green:134.0/255 blue:201.0/255 alpha:1],
                           kTokenizerTypeNumber: [UIColor colorWithRed:139.0/255 green:134.0/255 blue:201.0/255 alpha:1],
                           kTokenizerTypeKeyword: [UIColor colorWithRed:195.0/255 green:55.0/255 blue:149.0/255 alpha:1],
                           kTokenizerTypePreprocessor: [UIColor colorWithRed:198.0/255.0 green:124.0/255.0 blue:72.0/255.0 alpha:1],
                           kTokenizerTypeURL: [UIColor colorWithRed:35.0/255 green:63.0/255 blue:208.0/255 alpha:1],
                           kTokenizerTypeAttribute: [UIColor colorWithRed:103.0/255 green:135.0/255 blue:142.0/255 alpha:1],
                           kTokenizerTypeProject: [UIColor colorWithRed:146.0/255 green:199.0/255 blue:119.0/255 alpha:1],
                           kTokenizerTypeOther: [UIColor colorWithRed:0.0/255 green:175.0/255 blue:199.0/255 alpha:1],
                           kTokenizerTypeOtherClassNames :  [UIColor colorWithHex:@"04afc8" alpha:1],
                           kTokenizerTypeOtherMethodNames :  [UIColor colorWithHex:@"04afc8" alpha:1]
                           };
            break;
    }
    return themeColor;
}


@end

#pragma mark - Regex Helpers


@implementation NSMutableAttributedString (Regex)

- (void)removeAttribute:(NSString *)name withValue:(id)compareValue range:(NSRange)range
{
    [self enumerateAttribute:(NSString *)kCTForegroundColorAttributeName inRange:range options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isEqual:compareValue]) {
            [self removeAttribute:(NSString *)kCTForegroundColorAttributeName range:range];
        }
        
    }];
}


- (void)addRanges:(NSArray *)array withColor:(UIColor *)color
{
    for (NSValue *value in array) {
        [self removeAttribute:(NSString *)kCTForegroundColorAttributeName range:value.rangeValue];
        [self addAttribute:(NSString *)kCTForegroundColorAttributeName value:color range:value.rangeValue];
    }
}

- (void)addRanges:(NSArray *)array withAttributes:(NSDictionary *)dic
{
    for (NSValue *value in array) {
        if (value.rangeValue.location + value.rangeValue.length <= self.length){
            [self removeAttribute:(NSString *)kCTForegroundColorAttributeName range:value.rangeValue];
            [self addAttributes:dic range:value.rangeValue];
        }
    }
}

- (NSArray *)allMatchesOfPattern:(NSString *)pattern inString:(NSString *)string
{
    NSArray *mathces = [[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil] matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    
    return mathces;
}

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color andDescription:(NSString *)description
{
    [self addRegularExpressionWithPattern:pattern withColor:color options:0 andDescription:description];
}

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color group:(int)index range:(NSRange)range andDescription:(NSString *)description
{
    NSString *string = self.string;
    
    
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:nil];
    
    [expression enumerateMatchesInString:string options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [self addAttribute:(NSString *)kCTForegroundColorAttributeName value:color range:[result rangeAtIndex:index]];
    }];
}

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options andDescription:(NSString *)description
{
    [self addRegularExpressionWithPattern:pattern withColor:color options:options range:NSMakeRange(0, self.length) andDescription:description];
}

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options range:(NSRange)range andDescription:(NSString *)description
{
    NSString *string = self.string;
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];
    
    [expression enumerateMatchesInString:string options:options range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [self addAttribute:(NSString *)kCTForegroundColorAttributeName value:color range:result.range];
    }];
}

- (void)addRegularExpressionWithPattern:(NSString *)pattern withColor:(UIColor *)color range:(NSRange)range andDescription:(NSString *)description
{
    [self addRegularExpressionWithPattern:pattern withColor:color options:0 range:range andDescription:description];
}

@end
