ARG K6_IMAGE=k6
# hadolint ignore=DL3006
FROM $K6_IMAGE

WORKDIR /app
ARG TEST_FILE=test.js
COPY $TEST_FILE .

ENV TEST_ID K6_TIMESTREAM_DATABASE_NAME K6_TIMESTREAM_TABLE_NAME

CMD [ "run", "test.js", "-o", "timestream", "--verbose"]
