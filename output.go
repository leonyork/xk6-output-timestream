/**
 * K6 Extension that writes results to AWS Timestream.
 * Based on some of the outputs from the official K6
 * repo. See
 * https://github.com/grafana/k6/tree/master/output
 */

package timestream

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite/types"

	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite"

	"github.com/aws/aws-sdk-go-v2/config"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/sirupsen/logrus"

	"go.k6.io/k6/metrics"
	"go.k6.io/k6/output"
)

func init() {
	output.RegisterExtension("timestream", New)
}

type TimestreamWriteClient interface {
	WriteRecords(
		ctx context.Context,
		params *timestreamwrite.WriteRecordsInput,
		optFns ...func(*timestreamwrite.Options),
	) (*timestreamwrite.WriteRecordsOutput, error)
}

type Output struct {
	output.SampleBuffer

	periodicFlusher *output.PeriodicFlusher
	params          output.Params
	client          TimestreamWriteClient
	config          *Config
	logger          logrus.FieldLogger
}

func New(params output.Params) (output.Output, error) {
	extensionConfig, err := GetConsolidatedConfig(params.JSONConfig)
	if err != nil {
		return nil, err
	}

	awsConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}
	if extensionConfig.Region != "" {
		awsConfig.Region = extensionConfig.Region
	}

	client := timestreamwrite.NewFromConfig(awsConfig)

	return &Output{
		params: params,
		client: client,
		config: &extensionConfig,
		logger: params.Logger.WithField("component", "timestream"),
	}, nil
}

func (o *Output) Description() string {
	return fmt.Sprintf(
		"Timestream (%s:%s)",
		o.config.DatabaseName,
		o.config.TableName,
	)
}

func (o *Output) Start() error {
	o.logger.Debug("Starting...")

	pf, err := output.NewPeriodicFlusher(
		o.config.PushInterval.TimeDuration(),
		o.flushMetrics,
	)
	if err != nil {
		return err
	}
	o.logger.Debug("Started!")
	o.periodicFlusher = pf

	return nil
}

func (o *Output) Stop() error {
	o.logger.Debug("Stopping...")
	o.periodicFlusher.Stop()
	o.logger.Debug("Stopped!")
	return nil
}

/**
 * Controls the writing of metrics to the database
 */
func (o *Output) flushMetrics() {
	// See https://docs.aws.amazon.com/timestream/latest/developerguide/API_WriteRecords.html
	TIMESTREAM_MAX_BATCH_SIZE := 100
	samples := o.GetBufferedSamples()
	start := time.Now()
	var wg sync.WaitGroup
	var allRecords []types.Record
	for _, sc := range samples {
		samples := sc.GetSamples()
		o.logger.
			WithField("samples", len(samples)).
			Debug("Creating records for samples")

		records := o.createRecords(samples)
		allRecords = append(allRecords, records...)

		if len(allRecords) > TIMESTREAM_MAX_BATCH_SIZE {
			o.writeRecordsAsync(allRecords[:TIMESTREAM_MAX_BATCH_SIZE], &wg, &start)
			allRecords = allRecords[TIMESTREAM_MAX_BATCH_SIZE:]
		}
	}

	if len(allRecords) > 0 {
		o.writeRecordsAsync(allRecords, &wg, &start)
	}

	wg.Wait()
}

/**
 * Mapping from K6 metrics to AWS Timstream records
 */
func (o *Output) createRecords(samples []metrics.Sample) []types.Record {
	records := make([]types.Record, 0, len(samples))
	for _, sample := range samples {
		var dimensions []types.Dimension

		for tagKey, tagValue := range sample.Tags.CloneTags() {
			if len(strings.TrimSpace(tagValue)) == 0 {
				o.logger.Debug(fmt.Sprintf("Ignoring tag %s", tagKey))
				continue
			}

			dimensions = append(dimensions, types.Dimension{
				Name:  aws.String(tagKey),
				Value: aws.String(tagValue),
			})
		}

		records = append(records, types.Record{
			Dimensions:       dimensions,
			MeasureName:      aws.String(sample.Metric.Name),
			MeasureValue:     aws.String(fmt.Sprintf("%.6f", sample.Value)),
			MeasureValueType: "DOUBLE",
			Time: aws.String(
				fmt.Sprintf("%d", sample.GetTime().UnixNano()),
			),
			TimeUnit: "NANOSECONDS",
		})
	}
	return records
}

/**
 * We perform the save to the database in a separate
 * thread as the network call is orders of magnitude
 * slower than running on the CPU and can be done in
 * parallel. This ultimately means we don't end up
 * waiting for a long time after the tests have
 * finished for data to be written to the database
 */
func (o *Output) writeRecordsAsync(
	records []types.Record,
	waitGroup *sync.WaitGroup,
	startTime *time.Time,
) {
	waitGroup.Add(1)
	go func(recordsToSave *[]types.Record) {
		defer waitGroup.Done()
		o.logger.WithField("t", time.Since(*startTime)).
			WithField("count", len(*recordsToSave)).
			Debug("Starting write to timestream")

		err := o.writeRecords(*recordsToSave)

		if err != nil {
			o.logger.WithError(err).
				WithField("count", len(*recordsToSave)).
				Error("Timestream: failed to write")
			return
		}
		o.logger.WithField("t", time.Since(*startTime)).
			WithField("count", len(*recordsToSave)).
			Debug("Wrote metrics to timestream")
	}(&records)
}

func (o *Output) writeRecords(records []types.Record) error {
	writeRecordsInput := &timestreamwrite.WriteRecordsInput{
		DatabaseName: aws.String(o.config.DatabaseName),
		TableName:    aws.String(o.config.TableName),
		Records:      records,
	}

	_, err := o.client.WriteRecords(context.TODO(), writeRecordsInput)

	return err
}
