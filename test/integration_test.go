package timestream_test

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/timestreamquery"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/stretchr/testify/assert"
)

type Fixture struct {
	Query          string          `json:"query"`
	ExpectedResult [][]TypedResult `json:"testExpectedResult"`
	ExpectedRows   Result          `json:"testExpectedRows"`
	ExpectedCols   int             `json:"testExpectedCols"`
	Interval       string          `json:"testInterval"`
}

type Result struct {
	GreaterOrEqual int `json:">="`
	LessOrEqual    int `json:"<="`
}

type TypedResult struct {
	Result
	Type string `json:"type"`
}

type Fixtures map[string]Fixture

func TestFixtures(t *testing.T) {
	t.Parallel()

	fixtures, err := loadFixtures("./fixtures.json")
	if err != nil {
		t.Error(err)
	}

	client, err := initTimestream()
	if err != nil {
		t.Error(err)
	}

	for name, fixture := range *fixtures {
		name := name
		fixture := fixture
		t.Run(name, func(t *testing.T) {
			t.Parallel()

			var query string
			query = fixture.Query

			if fixture.Interval != "" {
				query = strings.Replace(query, "$__interval", fixture.Interval, -1)
			}

			query = strings.Replace(
				strings.Replace(
					strings.Replace(
						query,
						"$__filter",
						"test_type = 'integration-test'",
						-1,
					),
					"$__database",
					os.Getenv("K6_TIMESTREAM_DATABASE_NAME"),
					-1,
				),
				"$__table",
				os.Getenv("K6_TIMESTREAM_TABLE_NAME"),
				-1,
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

			assert.GreaterOrEqual(t, len(results.Rows), fixture.ExpectedRows.GreaterOrEqual)
			assert.LessOrEqual(t, len(results.Rows), fixture.ExpectedRows.LessOrEqual)

			for row := range fixture.ExpectedResult {

				assert.Equal(t, len(results.Rows[row].Data), fixture.ExpectedCols)

				for col := range fixture.ExpectedResult[row] {
					expectedResult := fixture.ExpectedResult[row][col]

					if expectedResult.Type == "INT" {
						result, err := strconv.Atoi(*results.Rows[row].Data[col].ScalarValue)
						if err != nil {
							t.Error(err)
						}
						assert.GreaterOrEqual(t, result, expectedResult.GreaterOrEqual)
						assert.LessOrEqual(t, result, expectedResult.LessOrEqual)
					} else if expectedResult.Type == "TIME" {
						isoFormat := fmt.Sprintf("%sZ", strings.Replace(*results.Rows[row].Data[col].ScalarValue, " ", "T", -1))
						_, err := time.Parse(time.RFC3339Nano, isoFormat)
						if err != nil {
							t.Error(err)
							t.Fail()
						}
					} else if expectedResult.Type == "DOUBLE" {
						result, err := strconv.ParseFloat(*results.Rows[row].Data[col].ScalarValue, 64)
						if err != nil {
							t.Error(err)
						}
						assert.GreaterOrEqual(t, result, float64(expectedResult.GreaterOrEqual))
						assert.LessOrEqual(t, result, float64(expectedResult.LessOrEqual))
					} else {
						t.Errorf("Unrecognised result type %s", expectedResult.Type)
						t.Fail()
					}
				}
			}
		})
	}
}

func loadFixtures(fileLocation string) (*Fixtures, error) {
	file, err := os.Open(fileLocation)
	if err != nil {
		return nil, err
	}

	decoder := json.NewDecoder(file)

	var fixtures Fixtures

	err = decoder.Decode(&fixtures)
	if err != nil {
		return nil, err
	}

	return &fixtures, nil
}

func initTimestream() (*timestreamquery.Client, error) {
	awsConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}

	client := timestreamquery.NewFromConfig(awsConfig)
	return client, nil
}
