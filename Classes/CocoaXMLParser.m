/*
     File: CocoaXMLParser.m
 Abstract: Subclass of iTunesRSSParser that uses the Foundation framework's NSXMLParser for parsing the XML data.
  Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2009 Apple Inc. All Rights Reserved.
 
*/

#import "CocoaXMLParser.h"
#import "Song.h"

// Class extension for private properties and methods.
@interface CocoaXMLParser ()

@property (nonatomic, retain) NSMutableString *currentString;
@property (nonatomic, retain) Song *currentSong;
@property (nonatomic, retain) NSDateFormatter *parseFormatter;

@end

@implementation CocoaXMLParser

+ (NSString *)parserName {
    return @"NSXMLParser";
}

+ (XMLParserType)parserType {
    return XMLParserTypeNSXMLParser;
}

@synthesize currentString, currentSong, parseFormatter;

- (void)downloadAndParse:(NSURL *)url {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    self.parseFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [parseFormatter setDateStyle:NSDateFormatterLongStyle];
    [parseFormatter setTimeStyle:NSDateFormatterNoStyle];
    // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
    // the date formatter must be set to US locale in order to parse the dates
    [parseFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"US"] autorelease]];
    [self performSelectorOnMainThread:@selector(downloadStarted) withObject:nil waitUntilDone:NO];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    [self performSelectorOnMainThread:@selector(downloadEnded) withObject:nil waitUntilDone:NO];
    parser.delegate = self;
    self.currentString = [[[NSMutableString alloc] initWithCapacity:32] autorelease];
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    [parser parse];
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
    [self performSelectorOnMainThread:@selector(addToParseDuration:) withObject:[NSNumber numberWithDouble:duration] waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(parseEnded) withObject:nil waitUntilDone:NO];
    [parser release];
    self.parseFormatter = nil;
    self.currentString = nil;
    self.currentSong = nil;
    [pool release];
}

// Constants for the XML element names that will be considered during the parse. 
// Declaring these as static constants reduces the number of objects created during the run
// and is less prone to programmer error.
static NSString *kName_Item = @"item";
static NSString *kName_Title = @"title";
static NSString *kName_Category = @"category";
static NSString *kName_Artist = @"itms:artist";
static NSString *kName_Album = @"itms:album";
static NSString *kName_ReleaseDate = @"itms:releasedate";

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *) qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:kName_Item]) {
        self.currentSong = [[[Song alloc] init] autorelease];
    } else if ([elementName isEqualToString:kName_Title] || [elementName isEqualToString:kName_Category] || [elementName isEqualToString:kName_Artist] || [elementName isEqualToString:kName_Album] || [elementName isEqualToString:kName_ReleaseDate]) {
        [currentString setString:@""];
        storingCharacters = YES;
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:kName_Item]) {
        [self performSelectorOnMainThread:@selector(parsedSong:) withObject:currentSong waitUntilDone:NO];
        // performSelectorOnMainThread: will retain the object until the selector has been performed
        // setting the local reference to nil ensures that the local reference will be released
        self.currentSong = nil;
    } else if ([elementName isEqualToString:kName_Title]) {
        currentSong.title = currentString;
    } else if ([elementName isEqualToString:kName_Category]) {
        currentSong.category = currentString;
    } else if ([elementName isEqualToString:kName_Artist]) {
        currentSong.artist = currentString;
    } else if ([elementName isEqualToString:kName_Album]) {
        currentSong.album = currentString;
    } else if ([elementName isEqualToString:kName_ReleaseDate]) {
        currentSong.releaseDate = [parseFormatter dateFromString:currentString];
    }
    storingCharacters = NO;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (storingCharacters) [currentString appendString:string];
}

/*
 A production application should include robust error handling as part of its parsing implementation.
 The specifics of how errors are handled depends on the application.
 */
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // Handle errors as appropriate for your application.
}


@end
