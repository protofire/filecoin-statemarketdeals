# Filesoin StateMarketDeals JSON dump

This chart will get StateMarketDeals JSON dump, compress and upload to S3.

It uses [filexp](https://github.com/aschmahmann/filexp) to dump the JSON file and compress it with [zstd](https://github.com/facebook/zstd). Due to how filexp is implemented, it should match the lotus fullnode version in order to work, otherwise you'll get an unknown actor error.

## TODO:

- Remove CID Checker
