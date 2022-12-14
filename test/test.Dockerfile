ARG K6_IMAGE=k6
FROM $K6_IMAGE

ARG TEST_FILE=test.js
COPY $TEST_FILE .

ENV K6_TIMESTREAM_DATABASE_NAME K6_TIMESTREAM_TABLE_NAME

CMD [ "run", "test.js", "-o", "timestream", "--verbose"]