//
//  MMViewController.m
//  UIImageViewTester
//
//  Created by Nick Bolton on 8/28/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import "MMViewController.h"
#import "MMCollectionViewCell.h"
#import "UIImageView+AFNetworking.h"

@interface MMViewController ()

@end

@implementation MMViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.collectionView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
//    [UIImageView clearSharedImageCache];
}

#pragma mark - UICollectionViewDataSource Conformance

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {

    return 10000;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    MMCollectionViewCell *cell = (MMCollectionViewCell *)
    [collectionView
     dequeueReusableCellWithReuseIdentifier:NSStringFromClass([MMCollectionViewCell class])
     forIndexPath:indexPath];

    // add row index as a query parameter to force a different cache key for each image

    NSString *urlString =
    [NSString stringWithFormat:@"http://lorempixel.com/512/512/?%d", indexPath.row];

    NSURL *url = [NSURL URLWithString:urlString];
    UIImage *placeholder = [UIImage imageNamed:@"placeholder"];
    [cell.imageView setImageWithURL:url placeholderImage:placeholder];

    return cell;
}

#pragma mark - UICollectionViewDelegate Conformance

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
}

@end
