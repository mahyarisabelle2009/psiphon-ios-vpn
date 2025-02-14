/*
 * Copyright (c) 2018, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "SkyRegionSelectionViewController.h"
#import "RegionAdapter.h"
#import "ImageUtils.h"
#import "PsiphonClientCommonLibraryHelpers.h"
#import "Strings.h"
#import "DispatchUtils.h"
#import "Psiphon-Swift.h"

#define FastestCountryCode @""

@implementation SkyRegionSelectionViewController {
    NSArray<Region *> *regions;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [Strings selectServerRegionTitle];
    [self populateRegionsArray];

    // Listen to notification from client common library for when regions are updated.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUpdateAvailableRegions)
                                                 name:kPsiphonAvailableRegionsNotification
                                               object:nil];
}

- (void)populateRegionsArray {
    
    // Locale for currently selected app language.
    NSLocale *appLangLocale = [SwiftDelegate.bridge getLocaleForCurrentAppLanguage];
    
    NSString *currentRegionCode = [[RegionAdapter sharedInstance] getSelectedRegion].code;

    regions = [[[[RegionAdapter sharedInstance] getRegions]
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Region *evaluatedObject,
          NSDictionary<NSString *, id> *bindings) {
            return evaluatedObject.serverExists;
    }]] sortedArrayUsingComparator:^NSComparisonResult(Region*  _Nonnull obj1, Region* _Nonnull obj2) {
        // Sorts the array alphabetically using current locale.
        NSString *region1Name;
        if ([obj1.code isEqualToString:FastestCountryCode]) {
            region1Name = @"";
        } else {
            region1Name = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:obj1.code];
        }
        
        NSString *region2Name;
        if ([obj2.code isEqualToString:FastestCountryCode]) {
            region2Name = @"";
        } else {
            region2Name = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:obj2.code];
        }
        
        return [region1Name compare:region2Name
                            options:kNilOptions
                              range:NSMakeRange(0, region1Name.length)
                             locale:appLangLocale];
    }];

    [regions enumerateObjectsUsingBlock:^(Region *r, NSUInteger idx, BOOL *stop) {
        if ([r.code isEqualToString:currentRegionCode]) {
            self.selectedIndex = idx;
            *stop = TRUE;
        }
    }];
}

- (NSUInteger)numberOfRows {
    return [regions count];
}

- (void)bindDataToCell:(UITableViewCell *)cell atRow:(NSUInteger)rowIndex {
    Region *r = regions[rowIndex];

    cell.textLabel.text = [[RegionAdapter sharedInstance] getLocalizedRegionTitle:r.code];
    cell.imageView.image = [ImageUtils regionFlagForResourceId:r.flagResourceId];
}

- (void)onSelectedRow:(NSUInteger)rowIndex {
    if (self.selectionHandler) {
        self.selectionHandler(rowIndex, regions[rowIndex], self);
    }
}

#pragma mark -

- (void)onUpdateAvailableRegions {
    dispatch_async_main(^{
        [self populateRegionsArray];
        [self reloadTableRows];
    });
}

@end
