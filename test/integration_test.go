package timestream

import (
	"context"
	"fmt"
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

	results, err := client.Query(
		context.TODO(),
		&timestreamquery.QueryInput{
			QueryString: aws.String(
				"SELECT CAST(SUM(measure_value::double) AS INT) FROM \"dev-xk6-output-timestream-test\".\"test\" WHERE measure_name = 'http_reqs'",
			),
		})

	if err != nil {
		t.Error(err)
	}

	//K6_ITERATIONS=400 with one http request per iteration, so expect 400 http requests
	assert.Equal(t, *results.Rows[0].Data[0].ScalarValue, fmt.Sprint(400))
}

func initTimestream() (*timestreamquery.Client, error) {
	awsConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}

	client := timestreamquery.NewFromConfig(awsConfig)
	return client, nil
}
