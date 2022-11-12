package timestream

import (
	"context"
	"io"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite"
	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite/types"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/assert"
	"go.k6.io/k6/metrics"
)

func TestDescription(t *testing.T) {
	t.Parallel()
	output := &Output{config: &Config{
		DatabaseName: "testdb",
		TableName:    "testtable",
	}}
	expected := "Timestream (testdb:testtable)"

	actual := output.Description()

	assert.Equal(t, expected, actual)
}

type TimestreamWriteClientMock struct {
	TimestreamWriteClient
	mockWriteRecords func(ctx context.Context,
		params *timestreamwrite.WriteRecordsInput,
		optFns ...func(*timestreamwrite.Options)) (*timestreamwrite.WriteRecordsOutput, error)
}

func (m *TimestreamWriteClientMock) WriteRecords(
	ctx context.Context,
	params *timestreamwrite.WriteRecordsInput,
	optFns ...func(*timestreamwrite.Options),
) (*timestreamwrite.WriteRecordsOutput, error) {
	return m.mockWriteRecords(ctx, params, optFns...)
}

type SampleContainerMock struct {
	mockGetSamples func() []metrics.Sample
}

func (m *SampleContainerMock) GetSamples() []metrics.Sample {
	return m.mockGetSamples()
}

type testOutput struct{ testing.TB }

func (to testOutput) Write(p []byte) (n int, err error) {
	to.Logf("%s", p)

	return len(p), nil
}

func NewTestOutput(t testing.TB) io.Writer {
	return testOutput{t}
}

func NewLogger(t testing.TB) *logrus.Logger {
	l := logrus.New()
	logrus.SetOutput(NewTestOutput(t))

	return l
}

func TestFlushMetricsBatching(t *testing.T) {
	type SampleContainerTest struct {
		sampleCount int
	}
	type WriteRecordTest struct {
		writeCount int
	}
	createSampleContainers := func(
		numSampleContainers int,
		numSamplesPerContainer int) []SampleContainerTest {
		sampleContainers := make([]SampleContainerTest, numSampleContainers)
		for i := range sampleContainers {
			sampleContainers[i] = SampleContainerTest{
				sampleCount: numSamplesPerContainer,
			}
		}
		return sampleContainers
	}
	createWriteRecords := func(numWrites ...int) []WriteRecordTest {
		writeRecords := make([]WriteRecordTest, len(numWrites))
		for i, num := range numWrites {
			writeRecords[i] = WriteRecordTest{
				writeCount: num,
			}
		}
		return writeRecords
	}
	tests := []struct {
		name                 string
		sampleContainers     []SampleContainerTest
		expectedWriteRecords []WriteRecordTest
	}{
		{
			name:                 "No sample containers should not write records to timestream",
			sampleContainers:     createSampleContainers(0, 0),
			expectedWriteRecords: createWriteRecords(),
		},
		{
			name:                 "No samples in one container should not write records to timestream",
			sampleContainers:     createSampleContainers(1, 0),
			expectedWriteRecords: createWriteRecords(),
		},
		{
			name:                 "One sample in one sample container should write once to timestream",
			sampleContainers:     createSampleContainers(1, 1),
			expectedWriteRecords: createWriteRecords(1),
		},
		{
			name:                 "100 samples in one sample container should write once with 100 records to timestream",
			sampleContainers:     createSampleContainers(1, 100),
			expectedWriteRecords: createWriteRecords(100),
		},
		{
			name:                 "One sample in each of 100 sample containers should write once with 100 records to timestream",
			sampleContainers:     createSampleContainers(100, 1),
			expectedWriteRecords: createWriteRecords(100),
		},
		{
			name:                 "One sample in each of 101 sample containers should write twice to timestream with the last write having 1 record",
			sampleContainers:     createSampleContainers(101, 1),
			expectedWriteRecords: createWriteRecords(100, 1),
		},
		{
			name:                 "Five samples in each of 20 sample containers should write once with 100 records to timestream",
			sampleContainers:     createSampleContainers(20, 5),
			expectedWriteRecords: createWriteRecords(100),
		},
		{
			name:                 "Six samples in each of 34 sample containers should write three times to timestream with the last write having 4 records",
			sampleContainers:     createSampleContainers(34, 6),
			expectedWriteRecords: createWriteRecords(100, 100, 4),
		},
	}

	for _, test := range tests {
		test := test
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()

			r := metrics.NewRegistry()
			sampleContainers := make([]metrics.SampleContainer, len(test.sampleContainers))
			for i, testSampleContainer := range test.sampleContainers {
				samples := make([]metrics.Sample, testSampleContainer.sampleCount)
				for j := range samples {
					samples[j] = metrics.Sample{
						TimeSeries: metrics.TimeSeries{
							Metric: r.MustNewMetric("test_metric", metrics.Counter),
							Tags: r.RootTagSet().
								With("key", "val"),
						},
						Time:  time.UnixMicro(int64(j)),
						Value: float64(i * j),
					}
				}
				sampleContainers[i] = &SampleContainerMock{
					mockGetSamples: func() []metrics.Sample { return samples },
				}
			}

			// Make the buffer a little longer than the number of writes we expect so that we don't just
			// hang if our test is slightly mis-matched with the code (and so we have more/less writes)
			queue := make(chan *timestreamwrite.WriteRecordsInput, len(test.expectedWriteRecords)+1)
			actualNumberOfWriteRecords := uint32(0)
			output := &Output{
				config: &Config{DatabaseName: "testdb", TableName: "testtable"},
				logger: NewLogger(t),
				client: &TimestreamWriteClientMock{
					mockWriteRecords: func(ctx context.Context, params *timestreamwrite.WriteRecordsInput, optFns ...func(*timestreamwrite.Options)) (*timestreamwrite.WriteRecordsOutput, error) {
						queue <- params
						return nil, nil
					},
				},
			}

			output.AddMetricSamples(sampleContainers)

			output.flushMetrics()

			close(queue)
			var actualWriteRecords = make([]timestreamwrite.WriteRecordsInput, actualNumberOfWriteRecords)
			for queueItem := range queue {
				actualWriteRecords = append(actualWriteRecords, *queueItem)
			}

			assert.Equal(t, len(test.expectedWriteRecords), len(actualWriteRecords))

			for _, expectedWriteRecord := range test.expectedWriteRecords {
				found := false
				for i, actualWriteRecord := range actualWriteRecords {
					if len(actualWriteRecord.Records) != expectedWriteRecord.writeCount {
						continue
					}
					found = true
					// Remove the found one from the list
					actualWriteRecords = append(actualWriteRecords[:i], actualWriteRecords[i+1:]...)
					break
				}
				if !found {
					assert.Failf(
						t,
						"Unable to find write record message",
						"Unable to find write record message with %d records in it",
						expectedWriteRecord.writeCount,
					)
				}
			}
		})
	}
}

func TestCreateRecords(t *testing.T) {
	r := metrics.NewRegistry()
	samples := []metrics.Sample{
		{
			TimeSeries: metrics.TimeSeries{
				Metric: r.MustNewMetric("test_metric1", metrics.Counter),
				Tags: r.RootTagSet().
					With("key1.1", "val1.1").
					With("key2.1", "val2.1"),
			},
			Time:  time.UnixMicro(int64(0)),
			Value: float64(1),
		},
		{
			TimeSeries: metrics.TimeSeries{
				Metric: r.MustNewMetric("test_metric2", metrics.Counter),
				Tags: r.RootTagSet().
					With("Empty String", "").
					With("key2.2", "val2.2"),
			},
			Time:  time.UnixMicro(int64(1)),
			Value: float64(2.2),
		},
	}

	expectedRecords := []types.Record{
		{
			Dimensions: []types.Dimension{
				{
					Name:  aws.String("key1.1"),
					Value: aws.String("val1.1"),
				},
				{
					Name:  aws.String("key2.1"),
					Value: aws.String("val2.1"),
				},
			},
			MeasureName:      aws.String("test_metric1"),
			MeasureValue:     aws.String("1.000000"),
			MeasureValueType: "DOUBLE",
			Time:             aws.String("0"),
			TimeUnit:         "NANOSECONDS",
		},
		{
			Dimensions: []types.Dimension{
				{
					Name:  aws.String("key2.2"),
					Value: aws.String("val2.2"),
				},
			},
			MeasureName:      aws.String("test_metric2"),
			MeasureValue:     aws.String("2.200000"),
			MeasureValueType: "DOUBLE",
			Time:             aws.String("1000"),
			TimeUnit:         "NANOSECONDS",
		},
	}

	output := &Output{
		config: &Config{DatabaseName: "testdb", TableName: "testtable"},
		logger: NewLogger(t),
	}

	records := output.createRecords(samples)

	assert.Len(t, records, len(expectedRecords))
	for recordIndex, record := range records {
		expectedRecord := expectedRecords[recordIndex]
		assert.Len(t, record.Dimensions, len(expectedRecord.Dimensions))

		for _, expectedDimension := range expectedRecord.Dimensions {
			var dimension *types.Dimension
			for _, potentialDimension := range record.Dimensions {
				if *potentialDimension.Name == *expectedDimension.Name {
					dimension = &potentialDimension
					break
				}
			}

			if dimension == nil {
				assert.Failf(
					t,
					"Dimension not found",
					"Dimension not found that matches expected with Name %s",
					*expectedDimension.Name,
				)
				continue
			}
			assert.Equal(t, *dimension.Value, *expectedDimension.Value)
		}

		assert.Equal(t, record.MeasureName, expectedRecord.MeasureName)
		assert.Equal(t, record.MeasureValue, expectedRecord.MeasureValue)
		assert.Equal(t, record.MeasureValueType, expectedRecord.MeasureValueType)
		assert.Equal(t, *record.Time, *expectedRecord.Time)
		assert.Equal(t, record.TimeUnit, expectedRecord.TimeUnit)
	}
}
