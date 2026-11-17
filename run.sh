#!/bin/sh

# Check mandatory environment variables
if [ -z "$FILE_NAME" ] || [ -z "$RPC_FULLNODE" ] || [ -z "$BUCKET_NAME" ]; then
  echo "FILE_NAME, RPC_FULLNODE, and BUCKET_NAME must be set. Exiting."
  exit 1
fi

# Handle DISABLE_SINGLE_DOCUMENT
FILEXP_FLAGS=""
if [ "$DISABLE_SINGLE_DOCUMENT" = "true" ]; then
  # Replace .json with .ndjson
  FILE_NAME="${FILE_NAME%.json}.ndjson"
else
  FILEXP_FLAGS="--single-document"
fi

TEMP_FILE_NAME=$(mktemp "$FILE_NAME.tmp.XXXXXX") || exit 1
TEMP_COMPRESSED_FILE_NAME="$TEMP_FILE_NAME.zst"
trap 'rm -f "$TEMP_FILE_NAME" "$TEMP_COMPRESSED_FILE_NAME"' 0
trap 'exit 1' HUP INT TERM

# Produce MarketDeals JSON files
echo "Producing $FILE_NAME using $RPC_FULLNODE"
START_TIME=$(date +%s.%N)

filexp dump-statemarketdeals \
    $FILEXP_FLAGS \
    --rpc-fullnode="$RPC_FULLNODE" > "$TEMP_FILE_NAME"

if [ $? -ne 0 ]; then
  echo "filexp command failed. Exiting."
  exit 1
fi

END_TIME=$(date +%s.%N)
echo "Producing JSON file(s) took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# Compress original file
COMPRESSED_FILE_NAME="$FILE_NAME.zst"
echo "Compressing $FILE_NAME to $COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
zstd -f -o "$TEMP_COMPRESSED_FILE_NAME" "$TEMP_FILE_NAME"
if [ $? -ne 0 ]; then
  echo "Compression of $FILE_NAME failed. Exiting."
  exit 1
fi
END_TIME=$(date +%s.%N)
echo "Compressing $FILE_NAME took: $(echo "$END_TIME - $START_TIME" | bc -l) seconds"

# Temporary files are private until they are ready for HTTP downloads.
if ! chmod 644 "$TEMP_FILE_NAME" "$TEMP_COMPRESSED_FILE_NAME"; then
  echo "Setting export permissions failed. Exiting."
  exit 1
fi

# Renaming within the same directory keeps each published file complete.
if ! mv -f "$TEMP_FILE_NAME" "$FILE_NAME" || \
   ! mv -f "$TEMP_COMPRESSED_FILE_NAME" "$COMPRESSED_FILE_NAME"; then
  echo "Publishing $FILE_NAME failed. Exiting."
  exit 1
fi

# Configure AWS CLI for optimal performance
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 64MB

# Upload compressed file
FILE_SIZE=$(stat -c%s "$COMPRESSED_FILE_NAME")
echo "Uploading $COMPRESSED_FILE_NAME ($FILE_SIZE bytes) to $BUCKET_NAME/$COMPRESSED_FILE_NAME"
START_TIME=$(date +%s.%N)
aws s3 cp "$COMPRESSED_FILE_NAME" "s3://$BUCKET_NAME/$COMPRESSED_FILE_NAME" \
    --expected-size "$FILE_SIZE" \
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
