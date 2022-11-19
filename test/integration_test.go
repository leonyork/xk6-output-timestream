package timestream

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/timestreamquery"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/stretchr/testify/assert"
)

func TestResults(t *testing.T) {
	t.Parallel()

	client, err := initTimestream()
	if err != nil {
		t.Error(err)
	}

	query := fmt.Sprintf(
		"SELECT CAST(SUM(measure_value::double) AS INT) FROM \"%s\".\"%s\" WHERE measure_name = 'http_reqs'",
		os.Getenv("K6_TIMESTREAM_DATABASE_NAME"),
		os.Getenv("K6_TIMESTREAM_TABLE_NAME"),
	)
	t.Log(query)

	results, err := client.Query(
		context.TODO(),
		&timestreamquery.QueryInput{
			QueryString: aws.String(query),
		})

	if err != nil {
		t.Error(err)
	}

	result, err := strconv.Atoi(*results.Rows[0].Data[0].ScalarValue)
	if err != nil {
		t.Error(err)
	}
	//K6_ITERATIONS=400 with one http request per iteration, so expect 400 http requests
	// but give a generous margin of - 5 for network/timestream errors.
	assert.GreaterOrEqual(t, result, 395)
	assert.LessOrEqual(t, result, 400)
}

func initTimestream() (*timestreamquery.Client, error) {
	awsConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}

	client := timestreamquery.NewFromConfig(awsConfig)
	return client, nil
}
