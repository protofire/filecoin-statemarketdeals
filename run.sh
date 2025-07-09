#!/bin/sh

# Check mandatory environment variables
if [ -z "$FILE_NAME" ] || [ -z "$RPC_FULLNODE" ] || [ -z "$BUCKET_NAME" ]; then
  echo "FILE_NAME, RPC_FULLNODE, and BUCKET_NAME must be set. Exiting."
  exit 1
fi

# Prepare optional verified-output flag
VERIFIED_OUTPUT_FLAG=""
if [ ! -z "$VERIFIED_FILE_NAME" ]; then
  VERIFIED_OUTPUT_FLAG="--verified-output=$VERIFIED_FILE_NAME"
fi

# Produce MarketDeals JSON files
echo "Producing $FILE_NAME ${VERIFIED_FILE_NAME:+and $VERIFIED_FILE_NAME} using $RPC_FULLNODE"
START_TIME=$(date +%s.%N)

filexp dump-statemarketdeals \
    --single-document \
    --rpc-fullnode=$RPC_FULLNODE \
    --output=$FILE_NAME \
    $VERIFIED_OUTPUT_FLAG

if [ $? -ne 0 ]; then
  echo "filexp command failed. Exiting."
  exit 1
fi

END_TIME=$(date +%s.%N)
echo "Producing JSON file(s) took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# Compress original file
COMPRESSED_FILE_NAME=$FILE_NAME.zst
echo "Compressing $FILE_NAME to $COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
zstd -o $COMPRESSED_FILE_NAME $FILE_NAME
if [ $? -ne 0 ]; then
  echo "Compression of $FILE_NAME failed. Exiting."
  exit 1
fi
END_TIME=$(date +%s.%N)
echo "Compressing $FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# Configure AWS CLI for optimal performance
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 64MB

# Upload original file
FILE_SIZE=$(stat -c%s $COMPRESSED_FILE_NAME)
echo "Uploading $COMPRESSED_FILE_NAME ($FILE_SIZE bytes) to $BUCKET_NAME/$COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
aws s3 cp $COMPRESSED_FILE_NAME s3://$BUCKET_NAME/$COMPRESSED_FILE_NAME \
    --expected-size $FILE_SIZE \
    --only-show-errors \
    --acl public-read
if [ $? -eq 0 ]; then
  echo "Upload of $COMPRESSED_FILE_NAME completed successfully."
else
  echo "Upload of $COMPRESSED_FILE_NAME failed."
  exit 2
fi
END_TIME=$(date +%s.%N)
echo "Uploading $COMPRESSED_FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# If VERIFIED_FILE_NAME is set, process it as well
if [ ! -z "$VERIFIED_FILE_NAME" ]; then
  COMPRESSED_VERIFIED_FILE_NAME=$VERIFIED_FILE_NAME.zst
  echo "Compressing $VERIFIED_FILE_NAME to $COMPRESSED_VERIFIED_FILE_NAME"
  START_TIME=$(date +%s.%N)
  zstd -o $COMPRESSED_VERIFIED_FILE_NAME $VERIFIED_FILE_NAME
  if [ $? -ne 0 ]; then
    echo "Compression of $VERIFIED_FILE_NAME failed. Exiting."
    exit 1
  fi
  END_TIME=$(date +%s.%N)
  echo "Compressing $VERIFIED_FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

  # Upload verified-only file
  VERIFIED_FILE_SIZE=$(stat -c%s $COMPRESSED_VERIFIED_FILE_NAME)
  echo "Uploading $COMPRESSED_VERIFIED_FILE_NAME ($VERIFIED_FILE_SIZE bytes) to $BUCKET_NAME/$COMPRESSED_VERIFIED_FILE_NAME"
  START_TIME=$(date +%s.%N)
  aws s3 cp $COMPRESSED_VERIFIED_FILE_NAME s3://$BUCKET_NAME/$COMPRESSED_VERIFIED_FILE_NAME \
      --expected-size $VERIFIED_FILE_SIZE \
      --only-show-errors \
      --acl public-read
  if [ $? -eq 0 ]; then
    echo "Upload of $COMPRESSED_VERIFIED_FILE_NAME completed successfully."
  else
    echo "Upload of $COMPRESSED_VERIFIED_FILE_NAME failed."
    exit 2
  fi
  END_TIME=$(date +%s.%N)
  echo "Uploading $COMPRESSED_VERIFIED_FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"
fi
