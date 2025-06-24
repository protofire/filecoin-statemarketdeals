#!/bin/sh

# Produce MarketDeals JSON
echo "Producing $FILE_NAME using $RPC_FULLNODE"
START_TIME=$(date +%s.%N)
filexp dump-statemarketdeals --single-document --rpc-fullnode=$RPC_FULLNODE > $FILE_NAME
if [ $? -ne 0 ]; then
  echo "Last command failed. Exiting."
  exit 1
fi
END_TIME=$(date +%s.%N)
echo "Producing $FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"



# Compress it
COMPRESSED_FILE_NAME=$FILE_NAME.zst
echo "Compressing $FILE_NAME to $COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
zstd -o $COMPRESSED_FILE_NAME $FILE_NAME
if [ $? -ne 0 ]; then
  echo "Last command failed. Exiting."
  exit 1
fi
END_TIME=$(date +%s.%N)
echo "Compressing $FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# Configure max performance for AWS CLI
# Set a large part size and enable concurrency
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 64MB

# Upload using aws s3 cp (auto handles multi-part and parallelism)
# --expected-size helps optimize transfer
FILE_SIZE=$(stat -c%s $COMPRESSED_FILE_NAME)
echo "Uploading $COMPRESSED_FILE_NAME ($FILE_SIZE bytes) to $BUCKET_NAME/$COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
aws s3 cp $COMPRESSED_FILE_NAME s3://$BUCKET_NAME/$COMPRESSED_FILE_NAME \
    --expected-size $FILE_SIZE \
    --only-show-errors \
    --acl public-read
# Check if upload succeeded
if [ $? -eq 0 ]; then
  echo "Upload completed successfully."
else
  echo "Upload failed."
  exit 2
fi
END_TIME=$(date +%s.%N)
echo "Uploading $COMPRESSED_FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"


